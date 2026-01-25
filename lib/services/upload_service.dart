import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bunny_cdn_service.dart';
import 'package:path_provider/path_provider.dart';
import 'tus_uploader.dart';

// Key used for storage
const String kQueueKey = 'upload_queue_v1';
const String kServiceNotificationChannelId = 'upload_service_channel';
const String kAlertNotificationChannelId = 'upload_alert_channel';
const int kServiceNotificationId = 888;
const String kPendingCourseKey = 'pending_course_v1';
const String kServiceStateKey = 'service_state_paused';

/// Initialize the background service
Future<void> initializeUploadService() async {
  final service = FlutterBackgroundService();

  // Create notification channel for Android (Silent Progress)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    kServiceNotificationChannelId,
    'Upload Status',
    description: 'Background upload progress',
    importance: Importance.low, 
  );
  
  // Create alert channel for Android (Success/Error)
  const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
    kAlertNotificationChannelId,
    'Upload Alerts',
    description: 'Finished uploads and errors',
    importance: Importance.high, 
    playSound: true,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(alertChannel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // Manual start is safer for isolate dependencies
      isForegroundMode: true,
      notificationChannelId: kServiceNotificationChannelId,
      initialNotificationTitle: 'Upload Service',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: kServiceNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );

  // Auto-Resume: Check if we have pending work (Crash Recovery)
  final prefs = await SharedPreferences.getInstance();
  
  final String? queueStr = prefs.getString(kQueueKey);
  final String? courseStr = prefs.getString(kPendingCourseKey);
  
  bool shouldStart = false;

  // 1. If we have a pending course creation workflow
  if (courseStr != null) {
     shouldStart = true;
  } 
  // 2. If we have active file uploads
  else if (queueStr != null) {
      try {
          final List<dynamic> queue = jsonDecode(queueStr);
          // Only start if tasks are actually WAITING or UPLOADING
          // Ignore 'completed', 'failed', or 'paused' (User can manual resume paused ones)
          final hasActiveTasks = queue.any((t) {
              final s = t['status'];
              return s == 'pending' || s == 'uploading';
          });
          
          if (hasActiveTasks) shouldStart = true;
      } catch (e) {
          print("Error parsing queue for auto-start: $e");
      }
  }

  if (shouldStart) {
    if (!await service.isRunning()) {
      print("🚀 [BG SERVICE] Auto-starting due to pending tasks...");
      await service.startService();
    }
  } else {
    // Force Stop if running but no tasks
     if (await service.isRunning()) {
        print(" [BG SERVICE] No active tasks but service is running. Stopping it.");
        service.invoke("stop"); 
     }
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  // Required for iOS
  return true;
}

 @pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  print("🏗️ [BG SERVICE] onStart triggered! Time: ${DateTime.now()}");
  
  // 1. DART CONTEXT READY
  DartPluginRegistrant.ensureInitialized();
  
  // 2. STATE INITIALIZATION (Fast)
  // Shared Prefs is usually fast enough, but we should still be careful.
  final prefs = await SharedPreferences.getInstance();
  List<Map<String, dynamic>> _queue = [];
  bool _isProcessing = false;
  bool _isPaused = false;
  final Map<String, CancelToken> _activeUploads = {};
  final bunnyService = BunnyCDNService();
  // TUS Uploader with Real Credentials
  final tusUploader = TusUploader(
    apiKey: 'eae59342-6952-4d56-bb2fb8745da1-adf7-402d', 
    libraryId: '583681',   
    videoId: '', // Will be generated per file or managed dynamically
  );
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Initialize Notifications immediately for instant feedback
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_bg_service_small'); // Use your icon
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 3. HELPER FUNCTIONS
  Future<void> _saveQueue() async {
    print("💾 [BG SERVICE] Saving Queue... size: ${_queue.length}");
    await prefs.setString(kQueueKey, jsonEncode(_queue));
    await prefs.setBool(kServiceStateKey, _isPaused);
    service.invoke('update', {'queue': _queue, 'isPaused': _isPaused});
  }

  void _broadcastQueue() {
    service.invoke('update', {'queue': _queue, 'isPaused': _isPaused});
  }

  Future<void> _updateNotification(String? specificStatus, int? specificProgress) async {
    if (Platform.isAndroid) {
      // 1. Calculate Stats
      int pending = 0;
      int uploading = 0;
      int failed = 0;
      int completed = 0;
      
      for (final t in _queue) {
          final s = t['status'];
          if (s == 'pending' && t['paused'] != true) pending++;
          else if (s == 'uploading') uploading++;
          else if (s == 'failed') failed++;
          else if (s == 'completed') completed++;
          else if (t['paused'] == true) pending++; // Treat paused as pending for count
      }

      final int total = _queue.length;
      
      // 1.5 Calculate Byte-Level Progress for smoothness
      double totalQueueBytes = 0;
      double uploadedQueueBytes = 0;
      for (final t in _queue) {
          double tTotal = (t['totalBytes'] ?? 0).toDouble();
          
          // CRITICAL: If totalBytes is missing (legacy tasks), try to get it now
          if (tTotal == 0) {
             try {
               final file = File(t['localPath'] ?? t['filePath'] ?? '');
               if (file.existsSync()) {
                 tTotal = file.lengthSync().toDouble();
                 t['totalBytes'] = tTotal.toInt(); // Cache it
               }
             } catch (_) {}
          }

          final double tUploaded = (t['uploadedBytes'] ?? 0).toDouble();
          totalQueueBytes += tTotal;
          if (t['status'] == 'completed') {
             uploadedQueueBytes += tTotal; 
          } else {
             uploadedQueueBytes += tUploaded;
          }
      }

      double overallProgress = (total == 0) ? 0 : (completed / total);
      if (totalQueueBytes > 1024) { // Only use bytes if we have a significant number
         overallProgress = uploadedQueueBytes / totalQueueBytes;
      }

      final int progressInt = specificProgress ?? (overallProgress * 100).toInt();

      // 2. Determine Title/Body based on priority
      String title = 'Upload Service';
      String body = '';

      if (_isPaused) {
         title = 'Uploads Paused ⏸️';
         body = 'The entire queue is currently on hold.';
         if (failed > 0) body += " ($failed failed ⚠️)";
      } else if (uploading > 0) {
         title = failed > 0 ? 'Upload Error ⚠️ ($progressInt%)' : 'Uploading Files ($progressInt%) 📤';
         if (uploading == 1) {
            try {
              final activeTask = _queue.firstWhere((t) => t['status'] == 'uploading');
              final name = activeTask['remotePath'].toString().split('/').last;
              body = "Now: $name";
              if (failed > 0) body += " • $failed Failed ⚠️";
            } catch (_) {
              body = "Processing 1 active task...";
            }
         } else {
            body = "$uploading Active • $pending Pending";
            if (failed > 0) body += " • $failed Failed ⚠️";
         }
      } else if (failed > 0) {
         title = 'Upload Issue ⚠️';
         body = '$failed files failed. Please check the app.';
      } else if (completed == total && total > 0) {
         title = 'All Uploads Complete! ✅';
         body = 'Safe to close the app now.';
      } else if (pending > 0) {
         title = 'Waiting to Start ⏳';
         body = '$pending files in queue.';
      } else {
         title = 'Upload Service';
         body = 'Ready for new tasks.';
      }

      // 3. Override with specific status if provided
      if (specificStatus != null && specificStatus.isNotEmpty) {
         body = specificStatus;
      }

      await flutterLocalNotificationsPlugin.show(
        kServiceNotificationId,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            kServiceNotificationChannelId,
            'Upload Status',
            icon: 'ic_bg_service_small',
            ongoing: uploading > 0 || _isPaused || failed > 0,
            showProgress: uploading > 0 || _isPaused,
            maxProgress: 100,
            progress: progressInt,
            priority: (uploading > 0 || _isPaused || failed > 0) ? Priority.high : Priority.low,
            importance: (uploading > 0 || _isPaused || failed > 0) ? Importance.high : Importance.low,
            color: const Color(0xFF2196F3),
            enableVibration: false,
          ),
        ),
      );
    }
  }
  final Map<String, int> _lastUiUpdates = {};

  // Helper Progress Handler
  void _handleProgress(int sent, int total, String taskId) {
    if (total > 0) {
      final progress = sent / total;
      final currentIdx = _queue.indexWhere((t) => t['id'] == taskId);
      
      if (currentIdx != -1) {
        _queue[currentIdx]['progress'] = progress;
        _queue[currentIdx]['uploadedBytes'] = sent;
        _queue[currentIdx]['totalBytes'] = total;
        
        // Throttling: Update UI only every 500ms
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastUpdate = _lastUiUpdates[taskId] ?? 0;
        
        if (now - lastUpdate > 500 || progress >= 1.0) {
           _lastUiUpdates[taskId] = now;
           _broadcastQueue();
           
           // Update Notification smoothly (every 1.5s to save battery)
           final lastNotif = _lastUiUpdates['__notification__'] ?? 0;
           if (now - lastNotif > 1500) {
               _lastUiUpdates['__notification__'] = now;
               _updateNotification(null, null);
           }
        }
      }
    }
  }

  // 🔥 INSTANT INITIAL UPDATE
  // This overwrites "Initializing..." with actual stats (e.g. "3 Pending") immediately.
  await _updateNotification(null, null);

  // 4. BOOTSTRAP DEPENDENCIES
  bool _depsReady = false;
  Future<void> _initDeps() async {
    try {
      print("🔥 [BG SERVICE] Initializing Dependencies...");
      await Firebase.initializeApp();
      print("🔥 [BG SERVICE] Firebase READY");
      
      /* Notifications already initialized at top */
      
      _depsReady = true;
      // Heartbeat removed
    } catch (e) {
      print("❌ [BG SERVICE] Dependency Init Failed: $e");
    }
  }

  // Define _triggerProcessing here...
  void _triggerProcessing() async {
    if (_isProcessing) return;
    if (!_depsReady) {
       print("⏳ [BG SERVICE] Waiting for dependencies before starting engine...");
       await _initDeps();
    }
    _isProcessing = true;
    const int kMaxConcurrent = 5; 

    print("🚀 [BG SERVICE] Engine Loop Started");
    final Connectivity connectivity = Connectivity();

    while (true) {
       // 1. QUICK CONNECTIVITY CHECK
       bool hasNoInternet = false;
       try {
         final results = await connectivity.checkConnectivity();
         hasNoInternet = results.contains(ConnectivityResult.none);
       } catch (e) {}
       
       if (hasNoInternet) {
          print("📡 [BG SERVICE] No Internet. Idle check (5s)...");
          await _updateNotification("Waiting for internet... 📡", null);
          for (int i=0; i<5; i++) {
             await Future.delayed(const Duration(seconds: 1));
             if (!_isProcessing) return; 
          }
          continue;
       }

      // Check if service was asked to stop via flag (optional)
       
      // 2. MASTER PAUSE (DECOUPLED)
      // We removed the 'if (_isPaused) continue' to allow individual tasks to resume
      // even if the master toggle is in 'Paused' state. Master toggle now acts as a batch command.

      // 3. FRESH COUNTS
      final pendingCount = _queue.where((t) => t['status'] == 'pending' && t['paused'] != true).length;
      final activeCount = _activeUploads.length;
      
      if (pendingCount == 0 && activeCount == 0) {
         // Check if everything is either completed or paused
         final bool allDoneOrPaused = _queue.every((t) => t['status'] == 'completed' || t['paused'] == true);
         final bool hasFailedTasks = _queue.any((t) => t['status'] == 'failed');

         if (allDoneOrPaused && _queue.isNotEmpty) {
            final bool allCompleted = _queue.every((t) => t['status'] == 'completed');
            if (allCompleted) {
                print("✅ [BG SERVICE] Every single task completed. Finalizing...");
                await _finalizeCourseIfPending();
                await _updateNotification("Course Published Successfully! ✅", 100);
            } else {
                print("⏸️ [BG SERVICE] Remaining tasks are PAUSED. Waiting 10s before sleep...");
                await _updateNotification("Uploads Paused ⏸️", null);
            }
            
            // 1. Release the lock so new triggers can wake the engine instantly
            _isProcessing = false;
            
            print("⏸️ [BG SERVICE] Tasks are PAUSED. Idle grace period (5s)...");
            for (int i = 0; i < 5; i++) {
                await Future.delayed(const Duration(seconds: 1));
                // Check if someone else woke up the engine
                if (_isProcessing) {
                   print("🚀 [BG SERVICE] Engine woken up by another trigger! Stopping this idle loop.");
                   return; 
                }
                final quickCheck = _queue.where((t) => t['status'] == 'pending' && t['paused'] != true).length;
                if (quickCheck > 0 || _activeUploads.isNotEmpty) {
                   print("🚀 [BG SERVICE] Instant wake-up detected! Re-triggering...");
                   _triggerProcessing();
                   return;
                }
            }

            service.invoke('all_completed');
            print("🛑 [BG SERVICE] Engine going to sleep (stopSelf).");
            service.stopSelf();
            return; 
         }

         if (hasFailedTasks) {
            _isProcessing = false; // Release lock for manual intervention
            print("ℹ️ [BG SERVICE] Actionable tasks 0, but FAILED tasks exist. Idle check (15s)...");
            for (int i = 0; i < 15; i++) {
                await Future.delayed(const Duration(seconds: 1));
                if (_isProcessing) return; 
                final quickCheck = _queue.where((t) => t['status'] == 'pending' && t['paused'] != true).length;
                if (quickCheck > 0) {
                   _triggerProcessing();
                   return;
                }
            }
            continue;
         }

         // Idle wait for new tasks (10s)
         _isProcessing = false; 
         for (int i = 0; i < 10; i++) {
            await Future.delayed(const Duration(seconds: 1));
            if (_isProcessing) return;
            if (_queue.where((t) => t['status'] == 'pending' && t['paused'] != true).isNotEmpty) {
               _triggerProcessing();
               return;
            }
         }
         
         if (_queue.isEmpty) {
             print("🛑 [BG SERVICE] Queue empty. Syncing and Stopping.");
             await _updateNotification("Ready for tasks 🚀", null);
             service.invoke('update', {'queue': _queue, 'isPaused': _isPaused});
             _isProcessing = false;
             await Future.delayed(const Duration(milliseconds: 500)); // Brief pause for UI delivery
             service.stopSelf();
             return;
         }
         continue;
      }

      // 2. MASTER PAUSE (DECOUPLED)
      // We removed the 'if (_isPaused) continue' to allow individual tasks to resume
      // even if the master toggle is in 'Paused' state. Master toggle now acts as a batch command.
      
      // 3. SLOT FILLING
      bool slotFilled = false;
      if (_activeUploads.length < kMaxConcurrent) {
         final now = DateTime.now().millisecondsSinceEpoch;
         
         // Re-scan for next task
         int nextIndex = _queue.indexWhere((t) => 
            t['status'] == 'pending' && 
            t['paused'] != true && 
            !_isPaused && // Master Gate: If global pause is ON, no NEW tasks start
            (t['retryAt'] == null || now > t['retryAt'])
         );

         if (nextIndex != -1) {
            final task = _queue[nextIndex];
            final String taskId = task['id'];
            print("📤 [BG SERVICE] Dispatching Task: $taskId");

            task['status'] = 'uploading';
            _queue[nextIndex] = task;
            await _saveQueue(); // Sync status change
            
            final cancelToken = CancelToken();
            _activeUploads[taskId] = cancelToken;
            slotFilled = true;
            int lastUiUpdate = 0;

             // Check File Type
             final String pathLower = task['filePath'].toString().toLowerCase();
             final bool isVideo = pathLower.endsWith('.mp4') || 
                                  pathLower.endsWith('.mov') || 
                                  pathLower.endsWith('.mkv') || 
                                  pathLower.endsWith('.avi');

             Future<String> uploadFuture;
             
             if (isVideo) {
                 // TUS for Videos (Stream)
                 uploadFuture = tusUploader.upload(
                    File(task['filePath']),
                    onProgress: (sent, total) => _handleProgress(sent, total, taskId),
                    cancelToken: cancelToken,
                 ).then((videoId) {
                    // TUS returns Video ID. Construct Playback URL.
                    return "https://iframe.mediadelivery.net/play/${tusUploader.libraryId}/$videoId";
                 });
             } else {
                 // Standard Storage for Images/PDFs
                 uploadFuture = bunnyService.uploadFile(
                    filePath: task['filePath'],
                    remotePath: task['remotePath'], // Uses the actual path structure for storage
                    onProgress: (sent, total) => _handleProgress(sent, total, taskId),
                    cancelToken: cancelToken,
                 );
             }
             // Safety breather to prevent battery-draining CPU spike
             await Future.delayed(const Duration(seconds: 1));

             uploadFuture.then((resultUrl) async {
               print("✅ [BG SERVICE] Upload Success: $resultUrl");
               
               _activeUploads.remove(taskId);
               final idx = _queue.indexWhere((t) => t['id'] == taskId);
               if (idx != -1) {
                 _queue[idx]['status'] = 'completed';
                 _queue[idx]['progress'] = 1.0;
                 _queue[idx]['url'] = resultUrl;
                 // Ensure bytes are synced on completion
                 if (_queue[idx]['totalBytes'] != null) {
                   _queue[idx]['uploadedBytes'] = _queue[idx]['totalBytes'];
                 }
                 
                 // If it was TUS, we might have a Video ID, but the URL is enough for now.
                 // For storage files, resultUrl is the CDN URL.
                 
                 await _saveQueue();
                 service.invoke('task_completed', {'id': taskId, 'url': resultUrl});
               }
               _triggerProcessing(); 
             }).catchError((e) async {
               final String errorStr = e.toString();
               final bool isMissingFile = errorStr.contains('File not found') || errorStr.contains('No such file');
               
               if (!isMissingFile) {
                  print("❌ [BG SERVICE] Task Error: $taskId | $e");
               } else {
                  print("⚠️ [BG SERVICE] Task Failed: File missing from device ($taskId)");
               }

               _activeUploads.remove(taskId);
               final currentIdx = _queue.indexWhere((t) => t['id'] == taskId);
               if (currentIdx != -1) {
                 final isNetworkError = e is DioException && 
                                        (e.type == DioExceptionType.connectionTimeout || 
                                         e.type == DioExceptionType.sendTimeout || 
                                         e.type == DioExceptionType.receiveTimeout ||
                                         e.type == DioExceptionType.connectionError);

                 if (e is DioException && e.type == DioExceptionType.cancel) {
                    _queue[currentIdx]['status'] = 'pending';
                    print("⏸️ [BG SERVICE] Task $taskId marked as pending (Cancelled)");
                 } else if (isNetworkError) {
                    _queue[currentIdx]['status'] = 'pending';
                    _queue[currentIdx]['error'] = "Network Issue - Auto Retrying...";
                    _queue[currentIdx]['retryAt'] = DateTime.now().add(const Duration(seconds: 15)).millisecondsSinceEpoch;
                    print("📡 [BG SERVICE] Network error for $taskId - Initializing Auto-Retry in 15s");
                 } else {
                    _queue[currentIdx]['status'] = 'failed';
                    _queue[currentIdx]['error'] = isMissingFile ? "File missing from device" : errorStr;
                    _queue[currentIdx]['retries'] = (_queue[currentIdx]['retries'] ?? 0) + 1;
                    _queue[currentIdx]['retryAt'] = DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch;
                 }
                 await _saveQueue();
               }
               _triggerProcessing();
            });
         }
      }

      // 4. Notification Update
      await _updateNotification(null, null);
      
      // Throttle the loop
      await Future.delayed(Duration(milliseconds: slotFilled ? 50 : 500));
    }
  }

  // 4. LISTENERS REGISTRATION (Priority Events)
  service.on('get_status').listen((event) {
     service.invoke('update', {'queue': _queue, 'isPaused': _isPaused});
     print("📊 [BG SERVICE] Status update sent to UI");
  });

  service.on('submit_course').listen((event) async {
    print("📥 [BG SERVICE] RECEIVED 'submit_course' EVENT!");
    if (event == null) return;
    
    // 1. Save Course Metadata
    final courseData = event['course'];
    print("📁 [BG SERVICE] Saving metadata for course: ${courseData?['title']}");
    await prefs.setString(kPendingCourseKey, jsonEncode(courseData));
    
    // 2. Add Files to Queue
    final List<dynamic> items = event['files'] ?? [];
    print("⚡ [BG SERVICE] Adding ${items.length} files to queue");
    for (var item in items) {
      // DUPLICATE CHECK: Skip if file already in queue (any status)
      final String filePath = item['filePath'];
      final bool alreadyExists = _queue.any((t) => t['filePath'] == filePath);
      
      if (!alreadyExists) {
        final task = Map<String, dynamic>.from(item);
        task['status'] = 'pending';
        task['progress'] = 0.0;
        task['retries'] = 0;
        
        // --- NEW: INITIAL SIZE DETECTION ---
        try {
          final file = File(filePath);
          if (file.existsSync()) {
            final size = file.lengthSync();
            task['totalBytes'] = size;
            task['uploadedBytes'] = 0;
          }
        } catch (_) {}
        
        _queue.add(task);
      } else {
        print("⚠️ [BG SERVICE] Skipping duplicate task: $filePath");
      }
    }
    await _saveQueue();
    
    // 3. Start
    _triggerProcessing();
    _updateNotification("Course Creation Started", 0);
  });

  service.on('add_task').listen((event) async {
    if (event == null) return;
    final String filePath = event['filePath'];
    final bool alreadyExists = _queue.any((t) => t['filePath'] == filePath);

    if (!alreadyExists) {
        final task = Map<String, dynamic>.from(event);
        task['status'] = 'pending';
        task['progress'] = 0.0;
        task['retries'] = 0;

        // --- NEW: INITIAL SIZE DETECTION ---
        try {
          final file = File(filePath);
          if (file.existsSync()) {
            final size = file.lengthSync();
            task['totalBytes'] = size;
            task['uploadedBytes'] = 0;
          }
        } catch (_) {}

        _queue.add(task);
        await _saveQueue();
        _triggerProcessing();
    } else {
        print("⚠️ [BG SERVICE] Skipped adding duplicate task via add_task: $filePath");
    }
  });

  service.on('cancel_all').listen((event) async {
    print("🔴 CANCEL ALL: Starting destructive cleanup...");
    
    // 1. Cancel Active Transfers
    for (var taskId in _activeUploads.keys.toList()) {
       print("🚫 [BG SERVICE] Cancelling task $taskId due to 'cancel_all'");
       _activeUploads[taskId]?.cancel('User cancelled all uploads');
    }
    _activeUploads.clear();

    // 2. DELETE UPLOADED FILES FROM SERVER (Aggressive Status-Independent)
    try {
      for (var task in _queue) {
         final String? assetUrl = task['url'];
         final String? remotePath = task['remotePath'];
         final String taskId = task['taskId'] ?? task['id'] ?? 'unknown';

         if (assetUrl != null && assetUrl.isNotEmpty && !assetUrl.startsWith('http')) {
            // Video record cleanup
            print("🎬 Bulk Cleanup: Deleting Video ID $assetUrl for task $taskId");
            await bunnyService.deleteVideo(
              libraryId: '583681', 
              videoId: assetUrl, 
              apiKey: 'eae59342-6952-4d56-bb2fb8745da1-adf7-402d'
            );
         } else if (remotePath != null && remotePath.isNotEmpty) {
            // Storage file cleanup
            print("📁 Bulk Cleanup: Deleting Storage Path $remotePath for task $taskId");
            await bunnyService.deleteFile(remotePath);
         }
      }
    } catch (e) {
       print("Bulk Server cleanup error: $e");
    }
    
    // 3. Clear Queue Logic
    _queue.clear();
    await _saveQueue();
    await _updateNotification("Uploads Cancelled", 0);
    
    // 4. Clear Course Metadata
    await prefs.remove(kPendingCourseKey);

    // 5. PHYSICAL CLEANUP (Delete pending_uploads folder contents)
    try {
       final directory = await getApplicationDocumentsDirectory();
       final pendingDir = Directory('${directory.path}/pending_uploads');
       if (await pendingDir.exists()) {
          final List<FileSystemEntity> content = pendingDir.listSync();
          for (var entity in content) {
             try {
                await entity.delete(recursive: true);
             } catch (_) {}
          }
       }
    } catch (e) {
       print("Local cleanup error: $e");
    }
    
    print("✅ Destructive cleanup complete!");
    service.invoke('update', {'queue': _queue, 'isPaused': _isPaused});
  });

  service.on('pause').listen((event) async {
    print("⏸️ [BG SERVICE] TRACE: Global PAUSE received. Data: $event");
    _isPaused = true;
    for (var taskId in _activeUploads.keys.toList()) {
      _activeUploads[taskId]?.cancel('User paused all uploads');
    }
    _activeUploads.clear();
    for (var task in _queue) {
      if (task['status'] == 'pending' || task['status'] == 'uploading') {
        task['paused'] = true;
        if (task['status'] == 'uploading') task['status'] = 'pending';
      }
    }
    await _saveQueue(); 
    await _updateNotification(null, null);
  });

  service.on('resume').listen((event) async {
    print("▶️ [BG SERVICE] TRACE: Global RESUME received. Data: $event");
    _isPaused = false;
    for (var task in _queue) {
      task['paused'] = false;
    }
    await _saveQueue();
    await _updateNotification(null, null);
    _triggerProcessing(); 
  });

  service.on('pause_task').listen((event) async {
    if (event == null || event['taskId'] == null) return;
    final String taskId = event['taskId'];
    print("⏸️ SERVICE RECEIVED pause_task: $taskId");
    final taskIndex = _queue.indexWhere((t) => (t['taskId'] ?? t['id']) == taskId);
    if (taskIndex != -1) {
      _queue[taskIndex]['paused'] = true;
      if (_activeUploads.containsKey(taskId)) {
        _activeUploads[taskId]?.cancel('User paused upload');
        _activeUploads.remove(taskId);
        _queue[taskIndex]['status'] = 'pending';
      }
      await _saveQueue();
      await _updateNotification(null, null);
    }
  });

  service.on('resume_task').listen((event) async {
    if (event == null || event['taskId'] == null) return;
    final String taskId = event['taskId'];
    print("✅ SERVICE RECEIVED resume_task: $taskId");
    final taskIndex = _queue.indexWhere((t) => (t['taskId'] ?? t['id']) == taskId);
    if (taskIndex != -1) {
      _queue[taskIndex]['paused'] = false;
      _queue[taskIndex]['retries'] = 0;
      _queue[taskIndex]['retryAt'] = null;
      if (_queue[taskIndex]['status'] == 'failed' || _queue[taskIndex]['status'] == 'uploading') {
        _queue[taskIndex]['status'] = 'pending';
      }
      await _saveQueue();
      await _updateNotification(null, null);
      _triggerProcessing(); 
    }
  });

      service.on('delete_task').listen((event) async {
         if (event == null || event['taskId'] == null) return;
         final taskId = event['taskId'];
         print("🗑️ SERVICE RECEIVED delete_task: $taskId");
         
         // 1. Cancel active upload
         if (_activeUploads.containsKey(taskId)) {
            print("🚫 Cancelling active upload for $taskId before delete");
            _activeUploads[taskId]?.cancel('User deleted task');
            _activeUploads.remove(taskId);
         }
         
         final taskIndex = _queue.indexWhere((t) => (t['taskId'] ?? t['id']) == taskId);
         if (taskIndex != -1) {
            final task = _queue[taskIndex];
            final String? remotePath = task['remotePath'];
            final String? assetUrl = task['url']; // Video ID or Storage URL
            
            // 2. Delete from Server (Aggressive Cleanup: Status doesn't matter)
            try {
               bool deletedFromServer = false;
               
               // Attempt server delete if we have ANY remote handle (ID or Path)
               if (assetUrl != null && assetUrl.isNotEmpty && !assetUrl.startsWith('http')) {
                  print("🎬 Status Independence: Deleting Video ID $assetUrl from Bunny Stream...");
                  deletedFromServer = await bunnyService.deleteVideo(
                    libraryId: '583681', 
                    videoId: assetUrl, 
                    apiKey: 'eae59342-6952-4d56-bb2fb8745da1-adf7-402d'
                  );
               } else if (remotePath != null && remotePath.isNotEmpty) {
                  print("📁 Status Independence: Deleting Storage Path $remotePath from Bunny...");
                  deletedFromServer = await bunnyService.deleteFile(remotePath);
               }
               
               if (deletedFromServer) print("✅ Server Cleanup SUCCESS for $taskId");
            } catch (e) {
               print("❌ Server delete error (Target might not exist yet): $e");
            }
            
            // 3. Remove from local queue (SAFE REMOVAL using taskId)
            _queue.removeWhere((t) => (t['taskId'] ?? t['id']) == taskId);
            
            // 4. Cleanup Metadata (Course JSON)
            final String? courseJson = prefs.getString(kPendingCourseKey);
            if (courseJson != null) {
               try {
                  final Map<String, dynamic> courseData = jsonDecode(courseJson);
                  final String? filePath = task['filePath'];
                  if (filePath != null) {
                     print("🧹 Cleaning up metadata for: $filePath");
                     _removeFileFromMetadata(courseData, filePath);
                     await prefs.setString(kPendingCourseKey, jsonEncode(courseData));
                  }
               } catch (e) {
                  print("❌ Metadata cleanup error: $e");
               }
            }

            // 5. Cleanup Local Safe Copy
            final String? localPath = task['filePath'];
            if (localPath != null && localPath.contains('pending_uploads')) {
               try {
                  final f = File(localPath);
                  if (await f.exists()) {
                     await f.delete();
                     print("🗑️ Deleted local safe copy: $localPath");
                  }
               } catch(e) {
                  print("❌ Local file delete error: $e");
               }
            }
            
            if (_queue.isEmpty) {
               print("💡 Queue empty after delete. Clearing pending course key.");
               await prefs.remove(kPendingCourseKey);
            }
            
            await _saveQueue();
            await _updateNotification(null, null);
            service.invoke('update', {'queue': _queue, 'isPaused': _isPaused});
            _triggerProcessing();
         } else {
            print("⚠️ Task not found in queue for deletion: $taskId");
         }
      });

  service.on('stop').listen((event) => service.stopSelf());

  // 5. HEAVY INITIALIZATION (Background)
  // 5. BOOTSTRAP (Parallel)
  _initDeps();

  // Heartbeat Timer removed per user request

  // RESTORE QUEUE
  final String? queueJson = prefs.getString(kQueueKey);
  if (queueJson != null) {
    try {
      _queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
      // Fix: Any task left in 'uploading' without a token should be 'pending'
      for (var task in _queue) if (task['status'] == 'uploading') task['status'] = 'pending';
    } catch (_) {}
  }
  
  service.invoke('update', {'queue': _queue, 'isPaused': _isPaused});
  
  // Wait a small bit for deps before first trigger
  Future.delayed(const Duration(seconds: 1), () {
     if (_queue.isNotEmpty) _triggerProcessing();
  });
}

// --- HELPER: Finalize Course ---
Future<void> _finalizeCourseIfPending() async {
  final prefs = await SharedPreferences.getInstance();
  final String? courseJson = prefs.getString(kPendingCourseKey);
  
  if (courseJson == null) return; // No pending course
  
  final queueJson = prefs.getString(kQueueKey);
  if (queueJson == null) return;
  final queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));

  // Check if any failed
  if (queue.any((t) => t['status'] == 'failed')) {
    // Retry or Fail? For now, we notify user to open app
    // We expect user to retry from UI if failed.
    return;
  }

  // Map: LocalPath -> RemoteURL
  final urlMap = <String, String>{};
  for (var task in queue) {
    if (task['status'] == 'completed' && task['url'] != null && task['filePath'] != null) {
      urlMap[task['filePath']] = task['url'];
    }
  }

  try {
     Map<String, dynamic> courseData = jsonDecode(courseJson);
     
     // 1. Update Top Level Images
     if (urlMap.containsKey(courseData['thumbnailUrl'])) {
       courseData['thumbnailUrl'] = urlMap[courseData['thumbnailUrl']];
     }
     if (urlMap.containsKey(courseData['certificateUrl1'])) {
       courseData['certificateUrl1'] = urlMap[courseData['certificateUrl1']];
     }
     if (urlMap.containsKey(courseData['certificateUrl2'])) {
       courseData['certificateUrl2'] = urlMap[courseData['certificateUrl2']];
     }

     // 2. Update Contents (Recursively or List)
     // Assuming flat list of contents in data because AddCourseScreen handles structure
     // But wait, CourseModel has `contents` which is List<Map>.
     // We need to traverse it.
     
     List<dynamic> contents = courseData['contents'] ?? [];
     _updateContentPaths(contents, urlMap);
     courseData['contents'] = contents;
     
     // 3. Update Demo Videos
     List<dynamic> demos = courseData['demoVideos'] ?? [];
     for (var demo in demos) {
        if (urlMap.containsKey(demo['path'])) {
           demo['path'] = urlMap[demo['path']];
           demo['isLocal'] = false;
        }
     }
     courseData['demoVideos'] = demos;

     // --- 3.5 NEW SAFETY CHECK: Ensure No Local Paths Remain ---
     bool hasLocalPaths = false;
     
     // Check Top Level
     if (courseData['thumbnailUrl'] != null && 
         courseData['thumbnailUrl'].toString().startsWith('/')) {
        hasLocalPaths = true;
     }

     // Check Contents
     hasLocalPaths = _checkForLocalPaths(contents);
     
     if (hasLocalPaths) {
       print("🛑 [BG SERVICE] SAFETY HALT: Course still contains local paths! Aborting publish.");
       // Ideally, notify user or retry logic here.
       // For now, we return to prevent corruption.
       return; 
     }

     // 4. Mark as Published and Active
     courseData['isPublished'] = true;
     courseData['status'] = 'active';

     // 5. Create in Firestore with proper Timestamp
     if (courseData.containsKey('createdAt')) {
        final rawDate = courseData['createdAt'];
        if (rawDate is String) {
           courseData['createdAt'] = Timestamp.fromDate(DateTime.parse(rawDate));
        }
     } else {
        courseData['createdAt'] = Timestamp.now();
     }
     
     final String? courseId = courseData['id'];
     
     if (courseId != null && courseId.isNotEmpty) {
        print("📁 Updating Firestore Record: courses/$courseId");
        await FirebaseFirestore.instance.collection('courses').doc(courseId).set(courseData);
        print("✅ Firestore Update SUCCESS!");
     } else {
        print("📁 Adding NEW Firestore Record...");
        final docRef = await FirebaseFirestore.instance.collection('courses').add(courseData);
        print("✅ Firestore Add SUCCESS! ID: ${docRef.id}");
     }
     
     // 5. Success!
     
     // CLEANUP: Delete temporary safe copies to free storage
     try {
       for (var localPath in urlMap.keys) {
          // Only delete files we created in our safe directory
          if (localPath.contains('pending_uploads')) {
             final f = File(localPath);
             if (await f.exists()) await f.delete();
          }
       }
     } catch(e) {
       print("Cleanup error (ignorable): $e");
     }

     // Clear Data
     await prefs.remove(kPendingCourseKey);
     await prefs.remove(kQueueKey); // Clear file queue too as job is done
     
     // Notify
     final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
     await flutterLocalNotificationsPlugin.show(
        kServiceNotificationId + 1, // Alert ID
        'Course Published! 🚀',
        'Your course "${courseData['title']}" is now live.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            kAlertNotificationChannelId,
            'Upload Alerts',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );

  } catch (e) {
     print("Finalization Error: $e");
     // Notify Error
  }
}

void _updateContentPaths(List<dynamic> contents, Map<String, String> urlMap) {
  for (var item in contents) {
     // Update Path
     if (item['path'] != null && urlMap.containsKey(item['path'])) {
       item['path'] = urlMap[item['path']];
       item['isLocal'] = false;
     }

     // Update Thumbnail
     if (item['thumbnail'] != null && urlMap.containsKey(item['thumbnail'])) {
       item['thumbnail'] = urlMap[item['thumbnail']];
     }
     
     // Recursion for folders
     if (item['type'] == 'folder' && item['contents'] != null) {
       _updateContentPaths(item['contents'], urlMap);
     }
  }
}

void _removeFileFromMetadata(Map<String, dynamic> data, String filePath) {
  // 1. Direct fields
  if (data['thumbnailUrl'] == filePath) data['thumbnailUrl'] = '';
  if (data['certificateUrl'] == filePath) data['certificateUrl'] = '';
  if (data['demoVideoUrl'] == filePath) data['demoVideoUrl'] = '';
  
  // Handling for specific course fields (if they exist in your structure)
  if (data['certificateUrl1'] == filePath) data['certificateUrl1'] = '';
  if (data['certificateUrl2'] == filePath) data['certificateUrl2'] = '';

  // 2. Demo Videos array
  if (data['demoVideos'] != null && data['demoVideos'] is List) {
     (data['demoVideos'] as List).removeWhere((d) => d['path'] == filePath);
  }

  // 3. Contents list recursively
  if (data['contents'] != null && data['contents'] is List) {
    _removeFileFromContentsRecursive(data['contents'], filePath);
  }
}

void _removeFileFromContentsRecursive(List<dynamic> contents, String filePath) {
  for (int i = contents.length - 1; i >= 0; i--) {
     final item = contents[i];
     if (item is! Map) continue;

     // If it's the exact file being deleted, remove it
     if (item['path'] == filePath || item['contentPath'] == filePath) {
        print("🧹 Metadata Cleanup: Removing $filePath from contents list");
        contents.removeAt(i);
        continue;
     }

     // If it's a thumbnail reference in an item, just clear it
     if (item['thumbnail'] == filePath) {
        print("🧹 Metadata Cleanup: Clearing thumbnail reference for $filePath");
        item['thumbnail'] = null;
     }

     // If it's a folder, recurse
     if (item['type'] == 'folder' && item['contents'] != null && item['contents'] is List) {
        _removeFileFromContentsRecursive(item['contents'], filePath);
     }
  }
}

bool _checkForLocalPaths(List<dynamic> contents) {
  for (var item in contents) {
    if (item is! Map) continue;
    
    // Check main path
    if (item['path'] != null && item['path'].toString().startsWith('/')) {
        print("⚠️ Found local path in content: ${item['name']}");
        return true;
    }

    // Check thumbnail if exists
    if (item['thumbnail'] != null && item['thumbnail'].toString().startsWith('/')) {
        print("⚠️ Found local thumbnail in content: ${item['name']}");
        return true;
    }

    // Recurse for folders
    if (item['type'] == 'folder' && item['contents'] != null) {
       if (_checkForLocalPaths(item['contents'])) return true;
    }
  }
  return false;
}
