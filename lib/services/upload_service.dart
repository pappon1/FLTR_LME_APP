import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bunny_cdn_service.dart';
import 'package:path_provider/path_provider.dart';
import 'tus_uploader.dart';
import 'dart:developer' as dev;
import 'dart:ui' show Color, DartPluginRegistrant;
import 'logger_service.dart';

// Key used for storage
const String kQueueKey = 'upload_queue_v1';
const String kServiceNotificationChannelId = 'upload_service_channel';
const String kAlertNotificationChannelId = 'upload_alert_channel';
const int kServiceNotificationId = 888;
const String kPendingCourseKey = 'pending_course_v1';
const String kPendingUpdateCourseKey = 'pending_update_course_v1';
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
          LoggerService.error("Error parsing queue for auto-start: $e", tag: 'BG_SERVICE');
      }
  }

  if (shouldStart) {
    if (!await service.isRunning()) {
      LoggerService.info("Auto-starting due to pending tasks...", tag: 'BG_SERVICE');
      await service.startService();
    }
  } else {
    // Force Stop if running but no tasks
     if (await service.isRunning()) {
        LoggerService.info("No active tasks but service is running. Stopping it.", tag: 'BG_SERVICE');
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
  LoggerService.info("onStart triggered! Time: ${DateTime.now()}", tag: 'BG_SERVICE');
  
  // 1. DART CONTEXT READY
  DartPluginRegistrant.ensureInitialized();
  
  // 2. STATE INITIALIZATION (Fast)
  // Shared Prefs is usually fast enough, but we should still be careful.
  final prefs = await SharedPreferences.getInstance();
  List<Map<String, dynamic>> queue = [];
  bool isProcessing = false;
  bool isPaused = false;
  final Map<String, CancelToken> activeUploads = {};
  final bunnyService = BunnyCDNService();
  // TUS Uploader with Real Credentials
  final tusUploader = TusUploader(
    apiKey: '0db49ca1-ac4b-40ae-9aa5d710ef1d-00ec-4077', 
    libraryId: '583681',   
    videoId: '', // Will be generated per file or managed dynamically
  );
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Initialize Notifications immediately for instant feedback
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_bg_service_small'); // Use your icon
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

  // 3. HELPER FUNCTIONS
  Future<void> saveQueue() async {
    LoggerService.info("Saving Queue... size: ${queue.length}", tag: 'BG_SERVICE');
    await prefs.setString(kQueueKey, jsonEncode(queue));
    await prefs.setBool(kServiceStateKey, isPaused);
    service.invoke('update', {'queue': queue, 'isPaused': isPaused});
  }

  void broadcastQueue() {
    service.invoke('update', {'queue': queue, 'isPaused': isPaused});
  }

  Future<void> updateNotification(String? specificStatus, int? specificProgress) async {
    if (Platform.isAndroid) {
      // 1. Calculate Stats
      int pending = 0;
      int uploading = 0;
      int failed = 0;
      int completed = 0;
      
      for (final t in queue) {
          final s = t['status'];
          if (s == 'pending' && t['paused'] != true) {
            pending++;
          } else if (s == 'uploading') {
            uploading++;
          } else if (s == 'failed') {
            failed++;
          } else if (s == 'completed') {
            completed++;
          } else if (t['paused'] == true) {
            pending++; // Treat paused as pending for count
          }
      }

      final int total = queue.length;
      
      // 1.5 Calculate Byte-Level Progress for smoothness
      double totalQueueBytes = 0;
      double uploadedQueueBytes = 0;
      for (final t in queue) {
          double tTotal = (t['totalBytes'] ?? 0).toDouble();
          
          // CRITICAL: If totalBytes is missing (legacy tasks), try to get it now
          if (tTotal == 0) {
             try {
               final file = File(t['localPath'] ?? t['filePath'] ?? '');
               if (file.existsSync()) {
                 tTotal = file.lengthSync().toDouble();
                 t['totalBytes'] = tTotal.toInt(); // Cache it
               }
             } catch (e) {
               LoggerService.warning("Error getting file size for task: $e", tag: 'BG_SERVICE');
             }
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

      if (isPaused) {
        title = 'Uploads Paused ⏸️';
        body = 'The entire queue is currently on hold.';
        if (failed > 0) body += " ($failed failed ⚠️)";
      } else if (uploading > 0) {
        title = failed > 0 ? 'Upload Error ⚠️ ($progressInt%)' : 'Uploading Files ($progressInt%) 📤';
        if (uploading == 1) {
          try {
            // Find the active task to show its name
            final currentTask = queue.firstWhere(
              (t) => t['status'] == 'uploading',
              orElse: () => {},
            );
            final taskName = currentTask['name'] ?? 'File';
            body = "Now: $taskName";
          } catch (e) {
            body = "Processing 1 active task...";
          }
          if (failed > 0) body += " • $failed Failed ⚠️";
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
        id: kServiceNotificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            kServiceNotificationChannelId,
            'Upload Status',
            icon: 'ic_bg_service_small',
            ongoing: uploading > 0 || isPaused || failed > 0,
            showProgress: uploading > 0 || isPaused,
            maxProgress: 100,
            progress: progressInt,
            priority: (uploading > 0 || isPaused || failed > 0) ? Priority.high : Priority.low,
            importance: (uploading > 0 || isPaused || failed > 0) ? Importance.high : Importance.low,
            color: const Color(0xFF2196F3),
            enableVibration: false,
          ),
        ),
      );
    }
  }
  final Map<String, int> lastUiUpdates = {};

  // Helper Progress Handler
  void handleProgress(int sent, int total, String taskId) {
    if (total > 0) {
      final progress = sent / total;
      final currentIdx = queue.indexWhere((t) => t['id'] == taskId);
      
      if (currentIdx != -1) {
        queue[currentIdx]['progress'] = progress;
        queue[currentIdx]['uploadedBytes'] = sent;
        queue[currentIdx]['totalBytes'] = total;
        
        // Throttling: Update UI only every 500ms
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastUpdate = lastUiUpdates[taskId] ?? 0;
        
        if (now - lastUpdate > 500 || progress >= 1.0) {
           lastUiUpdates[taskId] = now;
           broadcastQueue();
           
           // Update Notification smoothly (every 1.5s to save battery)
           final lastNotif = lastUiUpdates['__notification__'] ?? 0;
           if (now - lastNotif > 1500) {
               lastUiUpdates['__notification__'] = now;
               updateNotification(null, null);
           }
        }
      }
    }
  }

  // 🔥 INSTANT INITIAL UPDATE
  // This overwrites "Initializing..." with actual stats (e.g. "3 Pending") immediately.
  await updateNotification(null, null);

  // 4. BOOTSTRAP DEPENDENCIES
  bool depsReady = false;
  Future<void> initDeps() async {
    try {
      LoggerService.info("Initializing Dependencies...", tag: 'BG_SERVICE');
      await Firebase.initializeApp();
      LoggerService.success("Firebase READY", tag: 'BG_SERVICE');
      
      /* Notifications already initialized at top */
      
      depsReady = true;
      // Heartbeat removed
    } catch (e) {
      LoggerService.error("Dependency Init Failed: $e", tag: 'BG_SERVICE');
    }
  }

  // Define _triggerProcessing here...
  void triggerProcessing() async {
    if (isProcessing) return;
    if (!depsReady) {
       LoggerService.info("Waiting for dependencies before starting engine...", tag: 'BG_SERVICE');
       await initDeps();
    }
    isProcessing = true;
    const int kMaxConcurrent = 5; 

    LoggerService.info("Engine Loop Started", tag: 'BG_SERVICE');
    final Connectivity connectivity = Connectivity();

    while (true) {
       // 1. QUICK CONNECTIVITY CHECK
       bool hasNoInternet = false;
       try {
         final results = await connectivity.checkConnectivity();
         hasNoInternet = results.contains(ConnectivityResult.none);
       } catch (e) {
         LoggerService.warning("Network check failed: $e", tag: 'BG_SERVICE');
       }
       
       if (hasNoInternet) {
          LoggerService.info("No Internet. Idle check (5s)...", tag: 'BG_SERVICE');
          await updateNotification("Waiting for internet... 📡", null);
          for (int i=0; i<5; i++) {
             await Future.delayed(const Duration(seconds: 1));
             if (!isProcessing) return; 
          }
          continue;
       }

      // Check if service was asked to stop via flag (optional)
       
      // 2. MASTER PAUSE (DECOUPLED)
      // We removed the 'if (_isPaused) continue' to allow individual tasks to resume
      // even if the master toggle is in 'Paused' state. Master toggle now acts as a batch command.

      // 3. FRESH COUNTS
      final pendingCount = queue.where((t) => t['status'] == 'pending' && t['paused'] != true).length;
      final activeCount = activeUploads.length;
      
      if (pendingCount == 0 && activeCount == 0) {
         // Check if everything is either completed or paused
         final bool allDoneOrPaused = queue.every((t) => t['status'] == 'completed' || t['paused'] == true);
         final bool hasFailedTasks = queue.any((t) => t['status'] == 'failed');

         if (allDoneOrPaused && queue.isNotEmpty) {
            final bool allCompleted = queue.every((t) => t['status'] == 'completed');
            if (allCompleted) {
                LoggerService.info("Every single task completed. Finalizing...", tag: 'BG_SERVICE');
                bool isTargetPublished = false;
                try {
                  final String? cJson = prefs.getString(kPendingCourseKey);
                  if (cJson != null) {
                    final data = jsonDecode(cJson);
                    isTargetPublished = data['isPublished'] ?? false;
                  }
                } catch(_) {}

                await _finalizeCourseIfPending(service, queue, isPaused);
                await _finalizeUpdateIfPending(service, queue, isPaused);
                
                final msg = isTargetPublished 
                    ? "Course Published Successfully! ✅" 
                    : "Course Uploaded Successfully (Admin Side)! ✅";
                await updateNotification(msg, 100);
            } else {
                LoggerService.info("Remaining tasks are PAUSED. Waiting 10s before sleep...", tag: 'BG_SERVICE');
                await updateNotification("Uploads Paused ⏸️", null);
            }
            
            // 1. Release the lock so new triggers can wake the engine instantly
            isProcessing = false;
            
            LoggerService.info("Tasks are PAUSED. Idle grace period (5s)...", tag: 'BG_SERVICE');
            for (int i = 0; i < 5; i++) {
                await Future.delayed(const Duration(seconds: 1));
                // Check if someone else woke up the engine
                if (isProcessing) {
                   LoggerService.info("Engine woken up by another trigger! Stopping this idle loop.", tag: 'BG_SERVICE');
                   return; 
                }
                final quickCheck = queue.where((t) => t['status'] == 'pending' && t['paused'] != true).length;
                if (quickCheck > 0 || activeUploads.isNotEmpty) {
                   LoggerService.info("Instant wake-up detected! Re-triggering...", tag: 'BG_SERVICE');
                   triggerProcessing();
                   return;
                }
            }

            service.invoke('all_completed');
            LoggerService.info("Engine going to sleep (stopSelf).", tag: 'BG_SERVICE');
            // service.stopSelf(); // Disabled for debugging
            return; 
         }

         if (hasFailedTasks) {
            isProcessing = false; // Release lock for manual intervention
            LoggerService.info("Actionable tasks 0, but FAILED tasks exist. Idle check (15s)...", tag: 'BG_SERVICE');
            for (int i = 0; i < 15; i++) {
                await Future.delayed(const Duration(seconds: 1));
                if (isProcessing) return; 
                final quickCheck = queue.where((t) => t['status'] == 'pending' && t['paused'] != true).length;
                if (quickCheck > 0) {
                   triggerProcessing();
                   return;
                }
            }
            continue;
         }

         // Idle wait for new tasks (10s)
         isProcessing = false; 
         for (int i = 0; i < 10; i++) {
            await Future.delayed(const Duration(seconds: 1));
            if (isProcessing) return;
            if (queue.where((t) => t['status'] == 'pending' && t['paused'] != true).isNotEmpty) {
               triggerProcessing();
               return;
            }
         }
         
         if (queue.isEmpty) {
             LoggerService.info("Queue empty. Syncing and Stopping.", tag: 'BG_SERVICE');
             await updateNotification("Ready for tasks 🚀", null);
             service.invoke('update', {'queue': queue, 'isPaused': isPaused});
             isProcessing = false;
             await Future.delayed(const Duration(milliseconds: 500)); 
             return;
         }
         continue;
      }

      // 2. MASTER PAUSE (DECOUPLED)
      // We removed the 'if (_isPaused) continue' to allow individual tasks to resume
      // even if the master toggle is in 'Paused' state. Master toggle now acts as a batch command.
      
      // 3. SLOT FILLING
      bool slotFilled = false;
      if (activeUploads.length < kMaxConcurrent) {
         final now = DateTime.now().millisecondsSinceEpoch;
         
         // Re-scan for next task
         final int nextIndex = queue.indexWhere((t) => 
            t['status'] == 'pending' && 
            t['paused'] != true && 
            !isPaused && // Master Gate: If global pause is ON, no NEW tasks start
            (t['retryAt'] == null || now > t['retryAt'])
         );

         if (nextIndex != -1) {
            final task = queue[nextIndex];
            final String taskId = task['id'];
            LoggerService.info("Dispatching Task: $taskId", tag: 'BG_SERVICE');

            task['status'] = 'uploading';
            queue[nextIndex] = task;
            await saveQueue(); // Sync status change
            
            final cancelToken = CancelToken();
            activeUploads[taskId] = cancelToken;
            slotFilled = true;

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
                    onProgress: (sent, total) => handleProgress(sent, total, taskId),
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
                    onProgress: (sent, total) => handleProgress(sent, total, taskId),
                    cancelToken: cancelToken,
                 );
             }
             // Safety breather to prevent battery-draining CPU spike
             await Future.delayed(const Duration(seconds: 1));

             uploadFuture.then((resultUrl) async {
               LoggerService.success("Upload Success: $resultUrl", tag: 'BG_SERVICE');
               
               activeUploads.remove(taskId);
               final idx = queue.indexWhere((t) => t['id'] == taskId);
               if (idx != -1) {
                 queue[idx]['status'] = 'completed';
                 queue[idx]['progress'] = 1.0;
                 queue[idx]['url'] = resultUrl;
                 // Ensure bytes are synced on completion
                 if (queue[idx]['totalBytes'] != null) {
                   queue[idx]['uploadedBytes'] = queue[idx]['totalBytes'];
                 }
                 
                 // If it was TUS, we might have a Video ID, but the URL is enough for now.
                 // For storage files, resultUrl is the CDN URL.
                 
                 await saveQueue();
                 service.invoke('task_completed', {'id': taskId, 'url': resultUrl});
               }
               triggerProcessing(); 
             }).catchError((e) async {
               final String errorStr = e.toString();
               final bool isMissingFile = errorStr.contains('File not found') || errorStr.contains('No such file');
               
               if (!isMissingFile) {
                  print("❌ [BG SERVICE] Task Error: $taskId | $e");
               } else {
                  print("⚠️ [BG SERVICE] Task Failed: File missing from device ($taskId)");
               }

               activeUploads.remove(taskId);
               final currentIdx = queue.indexWhere((t) => t['id'] == taskId);
               if (currentIdx != -1) {
                 final isNetworkError = e is DioException && 
                                        (e.type == DioExceptionType.connectionTimeout || 
                                         e.type == DioExceptionType.sendTimeout || 
                                         e.type == DioExceptionType.receiveTimeout ||
                                         e.type == DioExceptionType.connectionError);

                 if (e is DioException && e.type == DioExceptionType.cancel) {
                    queue[currentIdx]['status'] = 'pending';
                    print("⏸️ [BG SERVICE] Task $taskId marked as pending (Cancelled)");
                 } else if (isNetworkError) {
                    queue[currentIdx]['status'] = 'pending';
                    queue[currentIdx]['error'] = "Network Issue - Auto Retrying...";
                    queue[currentIdx]['retryAt'] = DateTime.now().add(const Duration(seconds: 15)).millisecondsSinceEpoch;
                    LoggerService.info("Network error for $taskId - Initializing Auto-Retry in 15s", tag: 'BG_SERVICE');
                 } else {
                    queue[currentIdx]['status'] = 'failed';
                    queue[currentIdx]['error'] = isMissingFile ? "File missing from device" : errorStr;
                    queue[currentIdx]['retries'] = (queue[currentIdx]['retries'] ?? 0) + 1;
                    queue[currentIdx]['retryAt'] = DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch;
                 }
                 await saveQueue();
               }
               triggerProcessing();
            });
         }
      }

      // 4. Notification Update
      await updateNotification(null, null);
      
      // Throttle the loop
      await Future.delayed(Duration(milliseconds: slotFilled ? 50 : 500));
    }
  }

  // 4. LISTENERS REGISTRATION (Priority Events)
  service.on('get_status').listen((event) {
     service.invoke('update', {'queue': queue, 'isPaused': isPaused});
     LoggerService.info("Status update sent to UI", tag: 'BG_SERVICE');
  });

  service.on('submit_course').listen((event) async {
    if (event == null) return;
    // 1. Save Course Metadata
    final courseData = event['course'];
    LoggerService.info("Saving metadata for course: ${courseData?['title']}", tag: 'BG_SERVICE');
    await prefs.setString(kPendingCourseKey, jsonEncode(courseData));
    
    // 2. Add Files to Queue
    final List<dynamic> items = event['files'] ?? [];
    LoggerService.info("Adding ${items.length} files to queue", tag: 'BG_SERVICE');
    for (var item in items) {
      // DUPLICATE CHECK: Skip if file already in queue (any status)
      final String filePath = item['filePath'];
      final bool alreadyExists = queue.any((t) => t['filePath'] == filePath);
      
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
        
        queue.add(task);
      } else {
        LoggerService.warning("Skipping duplicate task: $filePath", tag: 'BG_SERVICE');
      }
    }
    await saveQueue();
    
    // 3. Start
    triggerProcessing();
    unawaited(updateNotification("Course Creation Started", 0));
  });

  service.on('update_course').listen((event) async {
    if (event == null) return;
    final updateData = event['updateData'];
    final String courseId = event['courseId'];
    updateData['id'] = courseId; // Ensure ID is present
    
    LoggerService.info("Saving update metadata for course: $courseId", tag: 'BG_SERVICE');
    await prefs.setString(kPendingUpdateCourseKey, jsonEncode(updateData));
    
    // 2. Add Files to Queue
    final List<dynamic> items = event['files'] ?? [];
    LoggerService.info("Adding ${items.length} files to queue (Update)", tag: 'BG_SERVICE');
    
    for (var item in items) {
      final String filePath = item['filePath'];
      final bool alreadyExists = queue.any((t) => t['filePath'] == filePath);
      
      if (!alreadyExists) {
        final task = Map<String, dynamic>.from(item);
        task['status'] = 'pending';
        task['progress'] = 0.0;
        task['retries'] = 0;
        
        try {
          final file = File(filePath);
          if (file.existsSync()) {
            final size = file.lengthSync();
            task['totalBytes'] = size;
            task['uploadedBytes'] = 0;
          }
        } catch (_) {}
        
        queue.add(task);
      }
    }
    await saveQueue();
    
    // 3. Start
    triggerProcessing();
    unawaited(updateNotification("Course Update Started", 0));
  });

  service.on('add_task').listen((event) async {
    if (event == null) return;
    final String filePath = event['filePath'];
    final bool alreadyExists = queue.any((t) => t['filePath'] == filePath);

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

        queue.add(task);
        await saveQueue();
        triggerProcessing();
    } else {
        LoggerService.warning("Skipped adding duplicate task via add_task: $filePath", tag: 'BG_SERVICE');
    }
  });

  service.on('cancel_all').listen((event) async {
    LoggerService.info("CANCEL ALL: Starting destructive cleanup...", tag: 'BG_SERVICE');
    
    // 1. Cancel Active Transfers
    for (var taskId in activeUploads.keys.toList()) {
       LoggerService.info("Cancelling task $taskId due to 'cancel_all'", tag: 'BG_SERVICE');
       activeUploads[taskId]?.cancel('User cancelled all uploads');
    }
    activeUploads.clear();

    // 2. DELETE UPLOADED FILES FROM SERVER (Aggressive Status-Independent)
    try {
      for (var task in queue) {
         final String? assetUrl = task['url'];
         final String? remotePath = task['remotePath'];
         final String taskId = task['taskId'] ?? task['id'] ?? 'unknown';

         if (assetUrl != null && assetUrl.isNotEmpty && !assetUrl.startsWith('http')) {
            // Video record cleanup
            LoggerService.info("Bulk Cleanup: Deleting Video ID $assetUrl for task $taskId", tag: 'BG_SERVICE');
            await bunnyService.deleteVideo(
              libraryId: '583681', 
              videoId: assetUrl, 
              apiKey: '0db49ca1-ac4b-40ae-9aa5d710ef1d-00ec-4077'
            );
         } else if (remotePath != null && remotePath.isNotEmpty) {
            // Storage file cleanup
            LoggerService.info("Bulk Cleanup: Deleting Storage Path $remotePath for task $taskId", tag: 'BG_SERVICE');
            await bunnyService.deleteFile(remotePath);
         }
      }
    } catch (e) {
       LoggerService.error("Bulk Server cleanup error: $e", tag: 'BG_SERVICE');
    }
    
    // 3. Clear Queue Logic
    queue.clear();
    await saveQueue();
    await updateNotification("Uploads Cancelled", 0);
    
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
       LoggerService.error("Local cleanup error: $e", tag: 'BG_SERVICE');
    }
    
    LoggerService.info("Destructive cleanup complete!", tag: 'BG_SERVICE');
    service.invoke('update', {'queue': queue, 'isPaused': isPaused});
  });

  service.on('pause').listen((event) async {
    LoggerService.info("Global PAUSE received. Data: $event", tag: 'BG_SERVICE');
    isPaused = true;
    for (var taskId in activeUploads.keys.toList()) {
      activeUploads[taskId]?.cancel('User paused all uploads');
    }
    activeUploads.clear();
    for (var task in queue) {
      if (task['status'] == 'pending' || task['status'] == 'uploading') {
        task['paused'] = true;
        if (task['status'] == 'uploading') task['status'] = 'pending';
      }
    }
    await saveQueue(); 
    await updateNotification(null, null);
  });

  service.on('resume').listen((event) async {
    LoggerService.info("Global RESUME received. Data: $event", tag: 'BG_SERVICE');
    isPaused = false;
    for (var task in queue) {
      task['paused'] = false;
    }
    await saveQueue();
    await updateNotification(null, null);
    triggerProcessing(); 
  });

  service.on('pause_task').listen((event) async {
    if (event == null || event['taskId'] == null) return;
    final String taskId = event['taskId'];
    LoggerService.info("SERVICE RECEIVED pause_task: $taskId", tag: 'BG_SERVICE');
    final taskIndex = queue.indexWhere((t) => (t['taskId'] ?? t['id']) == taskId);
    if (taskIndex != -1) {
      queue[taskIndex]['paused'] = true;
      if (activeUploads.containsKey(taskId)) {
        activeUploads[taskId]?.cancel('User paused upload');
        activeUploads.remove(taskId);
        queue[taskIndex]['status'] = 'pending';
      }
      await saveQueue();
      await updateNotification(null, null);
    }
  });

  service.on('resume_task').listen((event) async {
    if (event == null || event['taskId'] == null) return;
    final String taskId = event['taskId'];
    LoggerService.info("SERVICE RECEIVED resume_task: $taskId", tag: 'BG_SERVICE');
    final taskIndex = queue.indexWhere((t) => (t['taskId'] ?? t['id']) == taskId);
    if (taskIndex != -1) {
      queue[taskIndex]['paused'] = false;
      queue[taskIndex]['retries'] = 0;
      queue[taskIndex]['retryAt'] = null;
      if (queue[taskIndex]['status'] == 'failed' || queue[taskIndex]['status'] == 'uploading') {
        queue[taskIndex]['status'] = 'pending';
      }
      await saveQueue();
      await updateNotification(null, null);
      triggerProcessing(); 
    }
  });

  service.on('delete_task').listen((event) async {
    if (event == null || event['taskId'] == null) return;
    final taskId = event['taskId'];
    LoggerService.info("SERVICE RECEIVED delete_task: $taskId", tag: 'BG_SERVICE');
    
    // 1. Cancel active upload
    if (activeUploads.containsKey(taskId)) {
      LoggerService.warning("Cancelling active upload for $taskId before delete", tag: 'BG_SERVICE');
      activeUploads[taskId]?.cancel('User deleted task');
      activeUploads.remove(taskId);
    }
    
    final taskIndex = queue.indexWhere((t) => (t['taskId'] ?? t['id']) == taskId);
    if (taskIndex != -1) {
      final task = queue[taskIndex];
      final String? remotePath = task['remotePath'];
      final String? assetUrl = task['url']; 

      // 2. Delete from Server
      try {
        bool deletedFromServer = false;
        if (assetUrl != null && assetUrl.isNotEmpty && !assetUrl.startsWith('http')) {
          LoggerService.info("Deleting Video ID $assetUrl from Bunny Stream...", tag: 'BG_SERVICE');
          deletedFromServer = await bunnyService.deleteVideo(
            libraryId: '583681', 
            videoId: assetUrl, 
            apiKey: '0db49ca1-ac4b-40ae-9aa5d710ef1d-00ec-4077'
          );
        } else if (remotePath != null && remotePath.isNotEmpty) {
          LoggerService.info("Deleting Storage Path $remotePath from Bunny...", tag: 'BG_SERVICE');
          deletedFromServer = await bunnyService.deleteFile(remotePath);
        }
        if (deletedFromServer) LoggerService.success("Server Cleanup SUCCESS for $taskId", tag: 'BG_SERVICE');
      } catch (e) {
        LoggerService.error("Server delete error: $e", tag: 'BG_SERVICE');
      }
      
      // 3. Remove from local queue
      queue.removeWhere((t) => (t['id'] ?? t['taskId']) == taskId);
      
      // 4. Cleanup Metadata
      final String? courseJson = prefs.getString(kPendingCourseKey);
      if (courseJson != null) {
        try {
          final Map<String, dynamic> courseData = jsonDecode(courseJson);
          final String? filePath = task['filePath'];
          if (filePath != null) {
            _removeFileFromMetadata(courseData, filePath);
            await prefs.setString(kPendingCourseKey, jsonEncode(courseData));
          }
        } catch (e) {
          LoggerService.error("Metadata cleanup error: $e", tag: 'BG_SERVICE');
        }
      }

      // 5. Cleanup Local Safe Copy
      final String? localPath = task['filePath'];
      if (localPath != null && localPath.contains('pending_uploads')) {
        try {
          final f = File(localPath);
          if (await f.exists()) await f.delete();
        } catch(e) {
          LoggerService.warning("Local file delete error: $e", tag: 'BG_SERVICE');
        }
      }
      
      if (queue.isEmpty) {
        LoggerService.info("Queue empty after delete. Clearing pending course key.", tag: 'BG_SERVICE');
        await prefs.remove(kPendingCourseKey);
      }
      
      await saveQueue();
      await updateNotification(null, null);
      service.invoke('update', {'queue': queue, 'isPaused': isPaused});
      triggerProcessing();
    } else {
      LoggerService.warning("Task not found in queue for deletion: $taskId", tag: 'BG_SERVICE');
    }
  });

  service.on('stop').listen((event) => service.stopSelf());

  // 5. HEAVY INITIALIZATION (Background)
  // 5. BOOTSTRAP (Parallel)
  unawaited(initDeps());

  // Heartbeat Timer removed per user request

  // 🔥 RESTORE QUEUE IMMEDIATELY ON START (Before listeners)
  final String? queueJson = prefs.getString(kQueueKey);
  
  // Log Service Info for Debugging
  final dev.ServiceProtocolInfo info = await dev.Service.getInfo();
  LoggerService.info("VM Service URI: ${info.serverUri}", tag: 'BG_SERVICE');
  LoggerService.info("OS Process ID: $pid", tag: 'BG_SERVICE');
  
  // Save ID/URI to help with "restart later" and "terminated tracking"
  await prefs.setString('last_bg_service_uri', info.serverUri?.toString() ?? '');
  await prefs.setInt('last_bg_service_pid', pid);

  if (queueJson != null) {
    try {
      queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
      // Fix: Any task left in 'uploading' without a token should be 'pending'
      for (var task in queue) {
        if (task['status'] == 'uploading') task['status'] = 'pending';
      }
    } catch (_) {}
  }
  
  service.invoke('update', {'queue': queue, 'isPaused': isPaused});
  
  // Wait a small bit for deps before first trigger
  Future.delayed(const Duration(seconds: 1), () {
     if (queue.isNotEmpty) triggerProcessing();
  });
}

// --- HELPER: Finalize Course ---
Future<void> _finalizeCourseIfPending(ServiceInstance service, List<Map<String, dynamic>> queue, bool isPaused) async {
  final prefs = await SharedPreferences.getInstance();
  final String? courseJson = prefs.getString(kPendingCourseKey);
  
  if (courseJson == null) return; // No pending course
  
  final queueJson = prefs.getString(kQueueKey);
  if (queueJson == null) return;
  final List<Map<String, dynamic>> diskQueue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));

  // Check if any failed
  if (diskQueue.any((t) => t['status'] == 'failed')) {
    // Retry or Fail? For now, we notify user to open app
    // We expect user to retry from UI if failed.
    return;
  }

  // Map: LocalPath -> RemoteURL
  final urlMap = <String, String>{};
  for (var task in diskQueue) {
    if (task['status'] == 'completed' && task['url'] != null && task['filePath'] != null) {
      urlMap[task['filePath']] = task['url'];
    }
  }

  try {
     final Map<String, dynamic> courseData = jsonDecode(courseJson);
     
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
     
     final List<dynamic> contents = courseData['contents'] ?? [];
     _updateContentPaths(contents, urlMap);
     courseData['contents'] = contents;
     


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
       LoggerService.error("SAFETY HALT: Course still contains local paths! Aborting publish.", tag: 'BG_SERVICE');
       // Ideally, notify user or retry logic here.
       // For now, we return to prevent corruption.
       return; 
     }

     // 4. Respect UI Publish Intent
     final bool isTargetPublished = courseData['isPublished'] ?? false;
     courseData['isPublished'] = isTargetPublished;
     courseData['status'] = isTargetPublished ? 'active' : 'draft';

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
        LoggerService.info("Updating Firestore Record: courses/$courseId", tag: 'BG_SERVICE');
        await FirebaseFirestore.instance.collection('courses').doc(courseId).set(courseData);
        LoggerService.success("Firestore Update SUCCESS!", tag: 'BG_SERVICE');
     } else {
        LoggerService.info("Adding NEW Firestore Record...", tag: 'BG_SERVICE');
        final docRef = await FirebaseFirestore.instance.collection('courses').add(courseData);
        LoggerService.success("Firestore Add SUCCESS! ID: ${docRef.id}", tag: 'BG_SERVICE');
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
       LoggerService.warning("Cleanup error (ignorable): $e", tag: 'BG_SERVICE');
     }

     // Clear Data
     await prefs.remove(kPendingCourseKey);
     await prefs.remove(kQueueKey); // Clear file queue too as job is done
     
      // Update memory and notify UI
      queue.clear();
      service.invoke('update', {'queue': queue, 'isPaused': isPaused});
     
     // Notify
     final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
     final String alertTitle = isTargetPublished ? 'Course Published! 🚀' : 'Upload Successful! ✅';
     final String alertBody = isTargetPublished 
         ? 'Your course "${courseData['title']}" is now live.'
         : 'Course "${courseData['title']}" uploaded successfully (Admin Side).';

     await flutterLocalNotificationsPlugin.show(
        id: kServiceNotificationId + 1, // Alert ID
        title: alertTitle,
        body: alertBody,
        notificationDetails: const NotificationDetails(
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
     LoggerService.error("Finalization Error: $e", tag: 'BG_SERVICE');
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

  
  // Handling for specific course fields (if they exist in your structure)
  if (data['certificateUrl1'] == filePath) data['certificateUrl1'] = '';
  if (data['certificateUrl2'] == filePath) data['certificateUrl2'] = '';



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
        LoggerService.info("Metadata Cleanup: Removing $filePath from contents list", tag: 'BG_SERVICE');
        contents.removeAt(i);
        continue;
     }

     // If it's a thumbnail reference in an item, just clear it
     if (item['thumbnail'] == filePath) {
        LoggerService.info("Metadata Cleanup: Clearing thumbnail reference for $filePath", tag: 'BG_SERVICE');
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
        LoggerService.warning("Found local path in content: ${item['name']}", tag: 'BG_SERVICE');
        return true;
    }

    // Check thumbnail if exists
    if (item['thumbnail'] != null && item['thumbnail'].toString().startsWith('/')) {
        LoggerService.warning("Found local thumbnail in content: ${item['name']}", tag: 'BG_SERVICE');
        return true;
    }

    // Recurse for folders
    if (item['type'] == 'folder' && item['contents'] != null) {
       if (_checkForLocalPaths(item['contents'])) return true;
    }
  }
  return false;
}

Future<void> _finalizeUpdateIfPending(ServiceInstance service, List<Map<String, dynamic>> queue, bool isPaused) async {
  final prefs = await SharedPreferences.getInstance();
  final String? updateJson = prefs.getString(kPendingUpdateCourseKey);
  
  if (updateJson == null) return; 
  
  final queueJson = prefs.getString(kQueueKey);
  if (queueJson == null) return;
  final List<Map<String, dynamic>> diskQueue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));

  if (diskQueue.any((t) => t['status'] == 'failed')) return;

  final urlMap = <String, String>{};
  for (var task in diskQueue) {
    if (task['status'] == 'completed' && task['url'] != null && task['filePath'] != null) {
      urlMap[task['filePath']] = task['url'];
    }
  }

  try {
     final Map<String, dynamic> updateData = jsonDecode(updateJson);
     final String courseId = updateData['id'];

     if (urlMap.containsKey(updateData['thumbnailUrl'])) {
       updateData['thumbnailUrl'] = urlMap[updateData['thumbnailUrl']];
     }
     if (urlMap.containsKey(updateData['certificateUrl1'])) {
       updateData['certificateUrl1'] = urlMap[updateData['certificateUrl1']];
     }
     if (urlMap.containsKey(updateData['certificateUrl2'])) {
       updateData['certificateUrl2'] = urlMap[updateData['certificateUrl2']];
     }

     if (updateData.containsKey('contents')) {
        final List<dynamic> contents = updateData['contents'] ?? [];
        _updateContentPaths(contents, urlMap);
        updateData['contents'] = contents;
     }
     


     updateData.remove('id'); 

     LoggerService.info("Updating Firestore (Edit): courses/$courseId", tag: 'BG_SERVICE');
     await FirebaseFirestore.instance.collection('courses').doc(courseId).update(updateData);
     LoggerService.success("Firestore Update SUCCESS!", tag: 'BG_SERVICE');

     // Cleanup
     try {
       for (var localPath in urlMap.keys) {
          if (localPath.contains('pending_uploads')) {
             final f = File(localPath);
             if (await f.exists()) await f.delete();
          }
       }
     } catch(e) {
       LoggerService.warning("Cleanup (Update) error: $e", tag: 'BG_SERVICE');
     }

     await prefs.remove(kPendingUpdateCourseKey);
     await prefs.remove(kQueueKey);
     
     queue.clear();
     service.invoke('update', {'queue': queue, 'isPaused': isPaused});
     
     final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
     await flutterLocalNotificationsPlugin.show(
        id: kServiceNotificationId + 1,
        title: 'Update Complete! ✅',
        body: 'Course updated successfully.',
        notificationDetails: const NotificationDetails(
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
     LoggerService.error("Finalization (Update) Error: $e", tag: 'BG_SERVICE');
  }
}
