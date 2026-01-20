import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bunny_cdn_service.dart';
import 'package:path_provider/path_provider.dart';

// Key used for storage
const String kQueueKey = 'upload_queue_v1';
const String kPendingCourseKey = 'pending_course_v1'; // Metadata for course creation
const String kServiceNotificationChannelId = 'upload_service_channel';
const String kAlertNotificationChannelId = 'upload_alert_channel';
const int kServiceNotificationId = 888;

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
  final hasQueue = prefs.getString(kQueueKey) != null;
  final hasPendingCourse = prefs.getString(kPendingCourseKey) != null;

  if ((hasQueue || hasPendingCourse) && !await service.isRunning()) {
    await service.startService();
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  // Required for iOS
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure Dart is ready
  DartPluginRegistrant.ensureInitialized();
  
  // Initialize Firebase (Critical for Background Isolate)
  await Firebase.initializeApp();

  // Initialize Notifications for Background Isolate
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Initialize Bunny Service (Isolated Instance)
  final bunnyService = BunnyCDNService();
  
  // State
  List<Map<String, dynamic>> _queue = [];
  bool _isProcessing = false;
  bool _isPaused = false; // NEW: Pause state
  
  // Track active uploads with CancelTokens (for real pause/cancel)
  final Map<String, CancelToken> _activeUploads = {};

  // Load initial queue
  final prefs = await SharedPreferences.getInstance();

  // Helper to save queue (Must be defined before usage)
  Future<void> _saveQueue() async {
    await prefs.setString(kQueueKey, jsonEncode(_queue));
    // Broadcast update to UI
    service.invoke('update', {'queue': _queue});
  }

  final String? queueJson = prefs.getString(kQueueKey);
  if (queueJson != null) {
    _queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
    
    // SELF-HEALING: If service restarts, reset 'failed' tasks to 'pending' to give them another chance.
    // This prevents a deadlock where the service thinks it's done but the course isn't finalized.
    bool hasRestored = false;
    for (var task in _queue) {
       // Reset 'failed' OR 'uploading' (since we just restarted, nothing can be uploading yet)
       if (task['status'] == 'failed' || task['status'] == 'uploading') {
          task['status'] = 'pending';
          task['retries'] = 0;
          task['retryAt'] = null; // Reset wait timer
          task['paused'] = false; // Self-heal pause on restart if it was stuck
          hasRestored = true;
       }
    }
    if (hasRestored) await _saveQueue();
  }

  // Helper to update notification
  Future<void> _updateNotification(String status, int progress) async {
    if (Platform.isAndroid) {
      // If idle (no uploads), show minimal notification
      final bool isIdle = _queue.isEmpty || _queue.every((t) => t['status'] == 'completed' || t['status'] == 'failed');
      
      await flutterLocalNotificationsPlugin.show(
        kServiceNotificationId,
        isIdle ? 'Upload Service' : 'Uploading Course Files',
        isIdle ? 'Ready' : '$status ($progress%)',
        NotificationDetails(
          android: AndroidNotificationDetails(
            kServiceNotificationChannelId,
            'Upload Service',
            icon: 'ic_bg_service_small',
            ongoing: true,
            showProgress: !isIdle, // Hide progress bar when idle
            maxProgress: 100,
            progress: progress,
            priority: isIdle ? Priority.min : Priority.defaultPriority, // Lower priority when idle
            importance: isIdle ? Importance.min : Importance.low, // Minimal when idle
          ),
        ),
      );
    }
  }

  // --- Event Listeners ---

  // Processor Trigger
  // Processor Trigger
  void _triggerProcessing() async {
    if (_isProcessing) return;
    _isProcessing = true;
    const int kMaxConcurrent = 5; 

    while (true) {
      // 1. Check if we have active or pending work
      final pendingQueue = _queue.where((t) => t['status'] == 'pending' && t['paused'] != true).toList();
      final pendingCount = pendingQueue.length;
      final activeCount = _activeUploads.length;
      
      if (pendingCount == 0 && activeCount == 0) {
         // Check if anything is uploading or failed but retrying (not paused)
         bool hasPotentialWork = _queue.any((t) => 
            (t['status'] == 'uploading' && !_activeUploads.containsKey(t['id'])) || // Self-healing
            (t['status'] == 'pending' && t['paused'] != true)
         );

         if (!hasPotentialWork) {
            bool allFinished = _queue.isNotEmpty && _queue.every((t) => t['status'] == 'completed' || t['status'] == 'failed');
            if (allFinished) {
                print("✅ All tasks reached terminal state.");
                _isProcessing = false;
                await _finalizeCourseIfPending();
                await _updateNotification("Processing complete", 100);
                service.invoke('all_completed');
                
                // AUTO-STOP: Stop the service to remove notification
                print("🛑 All uploads complete. Stopping background service to clear notification...");
                await Future.delayed(const Duration(seconds: 2)); // Give time for finalization
                service.stopSelf(); // This will kill the service and remove notification
                break;
            }

            // If we are just idle, wait and re-check more frequently
            print("💤 Processor IDLE (No pending/active work). Sleeping...");
            await Future.delayed(const Duration(milliseconds: 800));
            
            // Final check before breaking loop
            if (!_queue.any((t) => (t['status'] == 'pending' && t['paused'] != true) || t['status'] == 'uploading')) {
               print("🛑 Stopping active processor loop.");
               _isProcessing = false;
               break;
            }
            continue;
         }
      }

      // 2. Inconsistent State Self-Healing
      for (var task in _queue) {
         if (task['status'] == 'uploading' && !_activeUploads.containsKey(task['id'])) {
            print("🔧 Self-Healing: Task ${task['id']} was stuck in 'uploading' without token. Resetting to 'pending'.");
            task['status'] = 'pending';
            task['progress'] = 0.0;
         }
      }

      // 3. Global Pause Check
      if (_isPaused) {
         print("⏸️ Engine is GLOBALLY PAUSED. Waiting...");
         await _updateNotification("Uploads Paused", 0);
         await Future.delayed(const Duration(seconds: 1)); 
         continue; 
      }
      
      // 3. Slot filling logic
      bool slotFilled = false;
      
      if (activeCount < kMaxConcurrent) {
         final now = DateTime.now().millisecondsSinceEpoch;
         
         // Aggressive Debug Log
         for(var t in _queue) {
            if (t['status'] == 'pending' || t['status'] == 'uploading') {
               print("🔎 Checking Task: ID=${t['id']} | Status=${t['status']} | Paused=${t['paused']} | RetryAt=${t['retryAt']} (Now=$now)");
            }
         }

         int nextIndex = _queue.indexWhere((t) => 
            t['status'] == 'pending' && 
            t['paused'] != true && 
            (t['retryAt'] == null || now > t['retryAt'])
         );

         if (nextIndex != -1) {
            final task = _queue[nextIndex];
            print("🚀 Starting upload for: ${task['id']}");
            final filePath = task['filePath'] as String;
            final remotePath = task['remotePath'] as String;
            final taskIndex = nextIndex;
            final taskId = task['id'];

            task['status'] = 'uploading';
            task['progress'] = 0.0; // Reset progress on start
            _queue[taskIndex] = task;
            await _saveQueue();
            
            final cancelToken = CancelToken();
            _activeUploads[taskId] = cancelToken;
            slotFilled = true;
            
            // Throttle progress updates to UI to every 500ms per task
            int lastUiUpdate = 0;

             bunnyService.uploadFile(
              filePath: filePath,
              remotePath: remotePath,
              cancelToken: cancelToken,
              onProgress: (sent, total) {
                 if (total > 0) {
                    final progress = sent / total;
                    _queue[taskIndex]['progress'] = progress;
                    
                    // Throttle UI update
                    final now = DateTime.now().millisecondsSinceEpoch;
                    if (now - lastUiUpdate > 800) {
                       lastUiUpdate = now;
                       service.invoke('update', {'queue': _queue});
                    }
                 }
              },
            ).then((url) async {
               _activeUploads.remove(taskId);
               _queue[taskIndex]['status'] = 'completed';
               _queue[taskIndex]['progress'] = 1.0;
               _queue[taskIndex]['url'] = url;
               await _saveQueue();
               service.invoke('task_completed', {'id': _queue[taskIndex]['id'], 'url': url});
               _triggerProcessing(); 
            }).catchError((e) async {
               _activeUploads.remove(taskId);
               
               final currentIdx = _queue.indexWhere((t) => t['id'] == taskId);
               if (currentIdx == -1) return;

               if (e is DioException && e.type == DioExceptionType.cancel) {
                  print("Upload Cancelled (Isolate): $taskId");
                  _queue[currentIdx]['status'] = 'pending';
                  await _saveQueue();
                  return;
               }

               _queue[currentIdx]['status'] = 'failed';
               _queue[currentIdx]['progress'] = 0.0;
               _queue[currentIdx]['error'] = (e as dynamic).toString();
               _queue[currentIdx]['retries'] = (_queue[currentIdx]['retries'] ?? 0) + 1;
               _queue[currentIdx]['retryAt'] = DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch;
               await _saveQueue();
               _triggerProcessing();
            });
         }
      }

      // 4. Update Notification Progress
      int completed = _queue.where((t) => t['status'] == 'completed').length;
      int total = _queue.length;
      if (total > 0) {
        int percent = ((completed / total) * 100).toInt();
        await _updateNotification("Uploading: ${_activeUploads.length} active", percent);
      }

      // 5. Flow Control
      if (!slotFilled) {
         await Future.delayed(const Duration(milliseconds: 1000));
      } else {
         await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  // --- Event Listeners ---

  // Add Item to Queue
  service.on('add_task').listen((event) async {
    if (event == null) return;
    final task = Map<String, dynamic>.from(event);
    task['status'] = 'pending';
    task['progress'] = 0.0;
    task['retries'] = 0;
    _queue.add(task);
    await _saveQueue();
    _triggerProcessing();
  });

  // Add Batch (Better for performance)
  service.on('add_batch').listen((event) async {
    if (event == null) return;
    final List<dynamic> items = event['items'] ?? [];
    for (var item in items) {
      final task = Map<String, dynamic>.from(item);
      task['status'] = 'pending';
      task['progress'] = 0.0;
      task['retries'] = 0;
      _queue.add(task);
    }
    await _saveQueue();
    _triggerProcessing();
  });

  // Clear Queue & DESTRUCT Server Files
  service.on('cancel_all').listen((event) async {
    print("🔴 CANCEL ALL: Starting destructive cleanup...");
    
    // 1. DELETE UPLOADED FILES FROM SERVER (Critical)
    try {
      final List<String> uploadedRemotePaths = [];
      for (var task in _queue) {
         if (task['status'] == 'completed' && task['url'] != null) {
            // Extract remote path from task
            final String remotePath = task['remotePath'];
            uploadedRemotePaths.add(remotePath);
         }
      }
      
      if (uploadedRemotePaths.isNotEmpty) {
        print("🗑️ Deleting ${uploadedRemotePaths.length} files from server...");
        for (var remotePath in uploadedRemotePaths) {
           try {
              final success = await bunnyService.deleteFile(remotePath);
              print(success ? "✅ Deleted: $remotePath" : "⚠️ Failed to delete: $remotePath");
           } catch (e) {
              print("❌ Server delete error: $e");
           }
        }
      }
    } catch (e) {
       print("Server cleanup error: $e");
    }
    
    // 2. Clear Queue Logic
    _queue.clear();
    await _saveQueue();
    await _updateNotification("Uploads Cancelled", 0);
    
    // 3. Clear Course Metadata
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPendingCourseKey);

    // 4. PHYSICAL CLEANUP (Delete pending_uploads folder contents)
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
  });

  // UI - Update Notification Proxy (Legacy support, though we act autonomously now)
  service.on('update_notification').listen((event) async {
     // Optional: If UI wants to force a status update
  });

  // Pause Uploads (Global - Cancel ALL active uploads)
  service.on('pause').listen((event) async {
      _isPaused = true;
      
      // Cancel ALL active uploads
      for (var taskId in _activeUploads.keys.toList()) {
         _activeUploads[taskId]?.cancel('User paused all uploads');
      }
      _activeUploads.clear();

      // Mark ALL pending/uploading tasks as paused (Full Sync)
      for (var task in _queue) {
         if (task['status'] == 'pending' || task['status'] == 'uploading') {
            task['paused'] = true;
            if (task['status'] == 'uploading') task['status'] = 'pending';
         }
      }
      await _saveQueue(); 
      
      // Broadcast change to UI
      service.invoke('update', {
         'queue': _queue,
         'isPaused': _isPaused,
      });
     
     _updateNotification("Uploads Paused", 0);
     print("⏸️ Uploads PAUSED (All active uploads cancelled)");
  });

  // Resume Uploads
  service.on('resume').listen((event) async {
     _isPaused = false;
     
     // Clear paused flag from ALL tasks (for UI sync)
     for (var task in _queue) {
        task['paused'] = false;
     }
     await _saveQueue(); // Save updated queue
     
     // Broadcast change to UI
     service.invoke('update', {
        'queue': _queue,
        'isPaused': _isPaused,
     });
     
     _triggerProcessing(); // Restart processing
     print("▶️ Uploads RESUMED");
  });

  // NEW: Status Request (For UI Sync)
  service.on('get_status').listen((event) {
     service.invoke('update', {
        'queue': _queue,
        'isPaused': _isPaused,
     });
     print("📊 Status update sent to UI");
  });

  // Pause Individual Task
  service.on('pause_task').listen((event) async {
     if (event == null || event['taskId'] == null) return;
     final taskId = event['taskId'];
     
     final taskIndex = _queue.indexWhere((t) => t['id'] == taskId);
     if (taskIndex != -1) {
         print("⏸️ SERVICE RECEIVED pause_task: $taskId");
         _queue[taskIndex]['paused'] = true;

         // If it's currently uploading, cancel it and move back to pending
         if (_activeUploads.containsKey(taskId)) {
            _activeUploads[taskId]?.cancel('User paused upload');
            _activeUploads.remove(taskId);
            _queue[taskIndex]['status'] = 'pending';
         }
         
         await _saveQueue();
         
         // Broadcast change to UI
         service.invoke('update', {
            'queue': _queue,
            'isPaused': _isPaused,
         });
         
         print("⏸️ Task PAUSED successfully: $taskId");
      }
  });

  // Resume Individual Task
  service.on('resume_task').listen((event) async {
     if (event == null || event['taskId'] == null) return;
     final taskId = event['taskId'];
     
     final taskIndex = _queue.indexWhere((t) => t['id'] == taskId);
      if (taskIndex != -1) {
         // Reset state to ensure IMMEDIATE retry
         _queue[taskIndex]['paused'] = false;
         _queue[taskIndex]['retries'] = 0;
         _queue[taskIndex]['retryAt'] = null;
         
         // Fix: If it was failed OR stuck in uploading, reset to pending
         if (_queue[taskIndex]['status'] == 'failed' || _queue[taskIndex]['status'] == 'uploading') {
            _queue[taskIndex]['status'] = 'pending';
         }
         
         print("✅ Task RESUMED (Immediate Ready): ${_queue[taskIndex]['id']}");
         
         // Decoupled: One task resume DOES NOT wake up the global engine.
         // If engine is global paused, this task remains 'pending' until global resume.
         
         await _saveQueue();
         
         // Broadcast change to UI
         service.invoke('update', {
            'queue': _queue,
            'isPaused': _isPaused,
         });
         
         _triggerProcessing(); 
      }
  });

  // NEW: Delete Individual Task (Destructive)
  service.on('delete_task').listen((event) async {
     print("🗑️ SERVICE RECEIVED delete_task: $event");
     if (event == null || event['taskId'] == null) return;
     final taskId = event['taskId'];
     
     // 1. Cancel active upload if it's currently uploading
     if (_activeUploads.containsKey(taskId)) {
        _activeUploads[taskId]?.cancel('User deleted task');
        _activeUploads.remove(taskId);
        print("🗑️ Task Upload CANCELLED (Deletion): $taskId");
     }
     
     final taskIndex = _queue.indexWhere((t) => t['id'] == taskId);
     if (taskIndex != -1) {
        final task = _queue[taskIndex];
        final remotePath = task['remotePath'];
        
        // 2. Delete from BunnyCDN server
        if (remotePath != null) {
           final bunny = BunnyCDNService();
           await bunny.deleteFile(remotePath);
           print("🗑️ Task DELETED from Server: $remotePath");
        }
        
        // 3. Remove from local queue
        _queue.removeAt(taskIndex);
        await _saveQueue();
        
        // 4. Cleanup Metadata: Ensure the file is removed from the course draft so it doesn't break finalization
        final String? courseJson = prefs.getString(kPendingCourseKey);
        if (courseJson != null) {
           try {
              final Map<String, dynamic> courseData = jsonDecode(courseJson);
              final String? filePath = task['filePath'];
              
              if (filePath != null) {
                 _removeFileFromMetadata(courseData, filePath);
                 await prefs.setString(kPendingCourseKey, jsonEncode(courseData));
                 print("🎯 Removed file from metadata: $filePath");
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
              if (await f.exists()) await f.delete();
              print("🧹 Deleted local safe copy: $localPath");
           } catch(e) {}
        }
        
        // 6. If queue is empty, clean up the pending course draft entirely
        if (_queue.isEmpty) {
           await prefs.remove(kPendingCourseKey);
           print("🧹 Queue empty, cleaned up course draft");
        }
        
        // 7. Broadcast change to UI
        service.invoke('update', {
           'queue': _queue,
           'isPaused': _isPaused,
        });
        
        print("🗑️ Task COMPLETELY REMOVED: $taskId");
     }
  });

  // Stop Service
  service.on('stop').listen((event) {
    service.stopSelf();
  });

  // Submit Course Job (The "Heavy" Request)
  service.on('submit_course').listen((event) async {
    if (event == null) return;
    
    // 1. Save Course Metadata
    final courseData = event['course'];
    await prefs.setString(kPendingCourseKey, jsonEncode(courseData));
    
    // 2. Add Files to Queue
    final List<dynamic> items = event['files'] ?? [];
    for (var item in items) {
      final task = Map<String, dynamic>.from(item);
      task['status'] = 'pending';
      task['progress'] = 0.0;
      task['retries'] = 0;
      _queue.add(task);
    }
    await _saveQueue();
    
    // 3. Start
    _triggerProcessing();
    _updateNotification("Course Creation Started", 0);
  });

  // Start processing immediately if tasks exist
  _triggerProcessing();
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

     // 4. Create in Firestore (Idempotent using 'id')
     // Ensure timestamps are preserved
     if (!courseData.containsKey('createdAt')) {
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
  // Normalize path for comparison (handling potential slashes differences)
  if (data['thumbnailUrl'] == filePath) data['thumbnailUrl'] = '';
  if (data['certificateUrl1'] == filePath) data['certificateUrl1'] = '';
  if (data['certificateUrl2'] == filePath) data['certificateUrl2'] = '';

  if (data['demoVideos'] != null) {
     final List<dynamic> demos = data['demoVideos'];
     demos.removeWhere((d) => d['path'] == filePath);
  }

  if (data['contents'] != null) {
     _removeFileFromContentsRecursive(data['contents'] as List<dynamic>, filePath);
  }
}

void _removeFileFromContentsRecursive(List<dynamic> contents, String filePath) {
  for (int i = contents.length - 1; i >= 0; i--) {
     final item = contents[i];
     if (item['type'] == 'folder' && item['contents'] != null) {
        _removeFileFromContentsRecursive(item['contents'] as List<dynamic>, filePath);
     } else {
        // Check if path or thumbnail matches
        if (item['path'] == filePath) {
           contents.removeAt(i);
        } else if (item['thumbnail'] == filePath) {
           item['thumbnail'] = null; // Just clear thumbnail, don't delete item
        }
     }
  }
}
