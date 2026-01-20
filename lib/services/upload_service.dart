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
import 'bunny_cdn_service.dart';

// Key used for storage
const String kQueueKey = 'upload_queue_v1';
const String kServiceNotificationChannelId = 'upload_service_channel';
const int kServiceNotificationId = 888;

/// Initialize the background service
Future<void> initializeUploadService() async {
  final service = FlutterBackgroundService();

  // Create notification channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    kServiceNotificationChannelId,
    'Upload Service',
    description: 'Running background uploads',
    importance: Importance.low, // Low importance to avoid sound/vibration on every update
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
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
      onBackground: onIosBackground,
    ),
  );
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

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize Bunny Service (Isolated Instance)
  final bunnyService = BunnyCDNService();
  
  // State
  List<Map<String, dynamic>> _queue = [];
  bool _isProcessing = false;

  // Load initial queue
  final prefs = await SharedPreferences.getInstance();
  final String? queueJson = prefs.getString(kQueueKey);
  if (queueJson != null) {
    _queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
  }

  // Helper to save queue
  Future<void> _saveQueue() async {
    await prefs.setString(kQueueKey, jsonEncode(_queue));
    // Broadcast update to UI
    service.invoke('update', {'queue': _queue});
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

    while (true) {
      // Find next pending task
      int? taskIndex;
      for (int i = 0; i < _queue.length; i++) {
        if (_queue[i]['status'] == 'pending') {
          taskIndex = i;
          break;
        }
      }

      if (taskIndex == null) {
        // All done
        _isProcessing = false;
        await _updateNotification("All uploads completed", 100);
        await Future.delayed(const Duration(seconds: 2));
        service.stopSelf(); // Auto-stop when done
        break;
      }

      // Process Task
      final task = _queue[taskIndex];
      final filePath = task['filePath'] as String;
      final remotePath = task['remotePath'] as String;
      final id = task['id'];

      // Mark as Uploading
      task['status'] = 'uploading';
      _queue[taskIndex] = task;
      await _saveQueue();

      try {
        await bunnyService.uploadFile(
          filePath: filePath,
          remotePath: remotePath,
          onProgress: (sent, total) {
            final progress = (sent / total);
            // Throttle updates to avoid DB spam
            if ((progress * 100).toInt() % 5 == 0) { // Every 5%
               _updateNotification("Uploading file ${taskIndex! + 1}/${_queue.length}", (progress * 100).toInt());
               // Note: We don't save to DB on every progress tick to save IO, just notification
            }
          },
        );

        // Success
        task['status'] = 'completed';
        
      } catch (e) {
        // Fail
        print("Upload Task Failed: $e");
        task['status'] = 'failed';
        task['error'] = e.toString();
      }

      // Update Queue State
      _queue[taskIndex] = task;
      await _saveQueue();
    }
  }

  // --- Event Listeners ---

  // Add Item to Queue
  service.on('add_task').listen((event) async {
    if (event == null) return;
    final task = Map<String, dynamic>.from(event);
    task['status'] = 'pending';
    task['progress'] = 0.0;
    _queue.add(task);
    await _saveQueue();
    _triggerProcessing();
  });

  // UI - Update Notification Proxy
  service.on('update_notification').listen((event) async {
     if (event == null) return;
     final String status = event['status'] ?? 'Running...';
     final int progress = event['progress'] ?? 0;
     await _updateNotification(status, progress);
  });

  // Stop Service
  service.on('stop').listen((event) {
    service.stopSelf();
  });

  // Start processing immediately if tasks exist
  _triggerProcessing();
}
