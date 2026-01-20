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
      autoStart: false, // Start only when needed
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

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize Bunny Service (Isolated Instance)
  final bunnyService = BunnyCDNService();
  
  // State
  List<Map<String, dynamic>> _queue = [];
  bool _isProcessing = false;

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

      // 2. Count Active Uploads
      int activeCount = _queue.where((t) => t['status'] == 'uploading').length;
      
         // 3. Fill Slots if available
      if (activeCount < kMaxConcurrent) {
         final now = DateTime.now().millisecondsSinceEpoch;
         int nextIndex = _queue.indexWhere((t) => 
            t['status'] == 'pending' && 
            (t['retryAt'] == null || now > t['retryAt'])
         );

         if (nextIndex != -1) {
            final task = _queue[nextIndex];
            final filePath = task['filePath'] as String;
            final remotePath = task['remotePath'] as String;
            final taskIndex = nextIndex; // Capture for closure

            // Mark as Uploading
            task['status'] = 'uploading';
            _queue[taskIndex] = task;
            await _saveQueue(); // Persist "In Progress"
            
            // Start Upload (Async - Fire and Forget, loop continues to fill more slots)
             bunnyService.uploadFile(
              filePath: filePath,
              remotePath: remotePath,
              onProgress: (sent, total) {
                // Determine overall progress for notification
                // Calculating total progress of 50GB files is expensive, just show file count or approximate
              },
            ).then((url) async {
               // Success
               _queue[taskIndex]['status'] = 'completed';
               _queue[taskIndex]['url'] = url; // Save URL
               await _saveQueue();
               
               // Notify UI
               service.invoke('task_completed', {'id': _queue[taskIndex]['id'], 'url': url});
               
               // Check if we need to spawn more
               _triggerProcessing(); 

            }).catchError((e) async {
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

  // Clear Queue
  service.on('cancel_all').listen((event) async {
    _queue.clear();
    await _saveQueue();
    await _updateNotification("Uploads Cancelled", 0);
  });

  // UI - Update Notification Proxy (Legacy support, though we act autonomously now)
  service.on('update_notification').listen((event) async {
     // Optional: If UI wants to force a status update
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
     courseData['createdAt'] = Timestamp.now(); 
     
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
