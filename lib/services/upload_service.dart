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
       if (task['status'] == 'failed') {
          task['status'] = 'pending';
          task['retries'] = 0;
          task['retryAt'] = null; // Reset wait timer
          hasRestored = true;
       }
    }
    if (hasRestored) await _saveQueue();
  }

  // Helper to update notification
  Future<void> _updateNotification(String status, int progress) async {
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.show(
        kServiceNotificationId,
        'Uploading Course Files',
        '$status ($progress%)',
        NotificationDetails(
          android: AndroidNotificationDetails(
            kServiceNotificationChannelId,
            'Upload Service',
            icon: 'ic_bg_service_small',
            ongoing: true,
            showProgress: true,
            maxProgress: 100,
            progress: progress,
          ),
        ),
      );
    }
  }

  // --- Event Listeners ---

  // Processor Trigger
  void _triggerProcessing() async {
    if (_isProcessing) return;
    _isProcessing = true;
    // WakelockPlus removed - Service Notification keeps it alive
    const int kMaxConcurrent = 5; // Speed Limit

    while (true) {
      // 1. Check if all done
      bool allComplete = _queue.any((t) => t['status'] == 'pending' || t['status'] == 'uploading');
      if (!allComplete) {
         if (_queue.isNotEmpty) {
             await _updateNotification("All uploads completed", 100);
             service.invoke('all_completed');
         }
         _isProcessing = false;
         break;
      }

      // 2. Pause Check
      if (_isPaused) {
         await _updateNotification("Uploads Paused", 0);
         await Future.delayed(const Duration(seconds: 2)); // Wait and check again
         continue; // Skip slot filling when paused
      }
      
      // 3. Count Active Uploads
      int activeCount = _queue.where((t) => t['status'] == 'uploading').length;
      
      // 4. Fill Slots if available
      if (activeCount < kMaxConcurrent) {
         final now = DateTime.now().millisecondsSinceEpoch;
         int nextIndex = _queue.indexWhere((t) => 
            t['status'] == 'pending' && 
            t['paused'] != true && // Skip paused tasks
            (t['retryAt'] == null || now > t['retryAt'])
         );

         if (nextIndex != -1) {
            final task = _queue[nextIndex];
            final filePath = task['filePath'] as String;
            final remotePath = task['remotePath'] as String;
            final taskIndex = nextIndex; // Capture for closure
            final taskId = task['id']; // Get task ID for tracking

            // Mark as Uploading
            task['status'] = 'uploading';
            _queue[taskIndex] = task;
            await _saveQueue(); // Persist "In Progress"
            
            // Create CancelToken for this upload
            final cancelToken = CancelToken();
            _activeUploads[taskId] = cancelToken;
            
            // Start Upload (Async - Fire and Forget, loop continues to fill more slots)
             bunnyService.uploadFile(
              filePath: filePath,
              remotePath: remotePath,
              cancelToken: cancelToken, // ENABLE CANCELLATION
              onProgress: (sent, total) {
                // Determine overall progress for notification
                // Calculating total progress of 50GB files is expensive, just show file count or approximate
              },
            ).then((url) async {
               // Success - Remove from active uploads
               _activeUploads.remove(taskId);
               
               _queue[taskIndex]['status'] = 'completed';
               _queue[taskIndex]['url'] = url; // Save URL
               await _saveQueue();
               
               // Notify UI
               service.invoke('task_completed', {'id': _queue[taskIndex]['id'], 'url': url});
               
               // Check if we need to spawn more
               _triggerProcessing(); 

            }).catchError((e) async {
               // Remove from active uploads
               _activeUploads.remove(taskId);
               
               // Check if it was cancelled (not a real error)
               if (e is DioException && e.type == DioExceptionType.cancel) {
                  print("Upload Cancelled: $taskId");
                  // Don't mark as failed, just leave as pending with paused flag
                  return;
               }
               
               print("Upload Fail: $e. Retrying...");
               
               int retries = _queue[taskIndex]['retries'] ?? 0;
               if (retries >= 10) { // Max 10 retries
                 _queue[taskIndex]['status'] = 'failed';
                 _queue[taskIndex]['error'] = e.toString();
                 await _updateNotification("Upload Failed: ${path.basename(filePath)}", 0);
               } else {
                 _queue[taskIndex]['retries'] = retries + 1;
                 _queue[taskIndex]['status'] = 'pending'; 
                 // Smart Backoff: Set specific time to retry
                 int waitSeconds = 5 + (retries * 5); // 5s, 10s, 15s...
                 _queue[taskIndex]['retryAt'] = DateTime.now().millisecondsSinceEpoch + (waitSeconds * 1000);
               }
               
               await _saveQueue();
               _triggerProcessing(); 
            });
            
            // Loop again immediately to fill next slot
            continue;
         }
      }
      
      // Wait a bit if full or nothing to do
      await Future.delayed(const Duration(seconds: 1));
      
      // Check again (loop condition handles exit)
      // Recalculate 'active' for loop break check
      // Check again (loop condition handles exit)
      // Recalculate 'active' for loop break check
      if (_queue.every((t) => t['status'] != 'pending' && t['status'] != 'uploading')) {
          _isProcessing = false;
          // WakelockPlus removed
          
          // --- ALL FILES UPLOADED: FINALIZE COURSE ---
          await _finalizeCourseIfPending();
          
          await _updateNotification("All tasks finished", 100);
          break;
      }
      
      // Update Notification with Summary
      int pending = _queue.where((t) => t['status'] == 'pending').length;
      int uploading = _queue.where((t) => t['status'] == 'uploading').length;
      int completed = _queue.where((t) => t['status'] == 'completed').length;
      int total = _queue.length;
      
      if (total > 0) {
         int percent = ((completed / total) * 100).toInt();
         await _updateNotification("Uploading: $uploading active, $pending pending", percent);
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
        print("⏸️ Cancelled upload: $taskId");
     }
     _activeUploads.clear();
     
     // Mark ALL pending/uploading tasks as paused (for UI sync)
     for (var task in _queue) {
        if (task['status'] == 'pending' || task['status'] == 'uploading') {
           task['paused'] = true;
           if (task['status'] == 'uploading') {
              task['status'] = 'pending'; // Reset uploading to pending
           }
        }
     }
     await _saveQueue(); // Save updated queue with paused flags
     
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
     
     // Cancel active upload if it's currently uploading
     if (_activeUploads.containsKey(taskId)) {
        _activeUploads[taskId]?.cancel('User paused upload');
        _activeUploads.remove(taskId);
        print("⏸️ Task Upload CANCELLED: $taskId");
     }
     
     final taskIndex = _queue.indexWhere((t) => t['id'] == taskId);
     if (taskIndex != -1) {
        _queue[taskIndex]['paused'] = true;
        // If it's uploading, change to pending so it won't be picked up
        if (_queue[taskIndex]['status'] == 'uploading') {
           _queue[taskIndex]['status'] = 'pending';
        }
        await _saveQueue();
        
        // Broadcast change to UI
        service.invoke('update', {
           'queue': _queue,
           'isPaused': _isPaused,
        });
        
        print("⏸️ Task PAUSED: $taskId");
     }
  });

  // Resume Individual Task
  service.on('resume_task').listen((event) async {
     if (event == null || event['taskId'] == null) return;
     final taskId = event['taskId'];
     
     final taskIndex = _queue.indexWhere((t) => t['id'] == taskId);
     if (taskIndex != -1) {
        _queue[taskIndex]['paused'] = false;
        await _saveQueue();
        
        // Broadcast change to UI
        service.invoke('update', {
           'queue': _queue,
           'isPaused': _isPaused,
        });
        
        _triggerProcessing(); // Restart processing to pick it up
        print("▶️ Task RESUMED: $taskId");
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
        await FirebaseFirestore.instance.collection('courses').doc(courseId).set(courseData);
     } else {
        // Fallback (Should not happen with new logic)
        courseData.remove('id'); 
        await FirebaseFirestore.instance.collection('courses').add(courseData);
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
