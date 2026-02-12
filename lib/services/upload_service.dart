import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Color, DartPluginRegistrant;
import 'dart:developer' as dev;

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

import 'bunny_cdn_service.dart';
import 'config_service.dart';
import 'logger_service.dart';
import 'tus_uploader.dart';

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
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alertChannel);
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
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
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
      LoggerService.error(
        "Error parsing queue for auto-start: $e",
        tag: 'BG_SERVICE',
      );
    }
  }

  if (shouldStart) {
    if (!await service.isRunning()) {
      LoggerService.info(
        "Auto-starting due to pending tasks...",
        tag: 'BG_SERVICE',
      );
      await service.startService();
    }
  } else {
    // Force Stop if running but no tasks
    if (await service.isRunning()) {
      LoggerService.info(
        "No active tasks but service is running. Stopping it.",
        tag: 'BG_SERVICE',
      );
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
  // 1. DART CONTEXT READY
  DartPluginRegistrant.ensureInitialized();

  // 🔥 INITIALIZE FIREBASE FOR BACKGROUND ISOLATE - MOVED TO initDeps TO PREVENT HANG
  // We don't await here so the service can report "Ready" status immediately.

  LoggerService.info(
    "onStart triggered! Time: ${DateTime.now()}",
    tag: 'BG_SERVICE',
  );

  // 2. STATE INITIALIZATION (Fast)
  // Shared Prefs is usually fast enough, but we should still be careful.
  final prefs = await SharedPreferences.getInstance();
  List<Map<String, dynamic>> queue = [];
  bool isProcessing = false;
  bool isPaused = false;
  final Map<String, CancelToken> activeUploads = {};
  final bunnyService = BunnyCDNService();
  // TUS Uploader - Initialized with empty keys, populated in initDeps
  TusUploader tusUploader = TusUploader(apiKey: '', libraryId: '', videoId: '');

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize Notifications immediately for instant feedback
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  // 3. HELPER FUNCTIONS
  Future<void> saveQueue() async {
    LoggerService.info(
      "Saving Queue... size: ${queue.length}",
      tag: 'BG_SERVICE',
    );
    await prefs.setString(kQueueKey, jsonEncode(queue));
    await prefs.setBool(kServiceStateKey, isPaused);
    service.invoke('update', {'queue': queue, 'isPaused': isPaused});
  }

  void broadcastQueue() {
    service.invoke('update', {'queue': queue, 'isPaused': isPaused});
  }

  // 🔥 NEW: Signal that service is fully booted and ready for commands
  service.invoke('service_ready');
  LoggerService.success("Service READY signal sent", tag: 'BG_SERVICE');

  Future<void> updateNotification(
    String? specificStatus,
    int? specificProgress,
  ) async {
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

      // 1.5 Smart Mix Progress (Average of individual task completion percentages)
      double sumProgress = 0;
      for (final t in queue) {
        final s = t['status'];
        if (s == 'completed') {
          sumProgress += 1.0;
        } else {
          // For uploading, pending, or failed, use its current progress value
          final double p = (t['progress'] ?? 0.0).toDouble();
          sumProgress += p;
        }
      }

      final double overallProgress = (total == 0) ? 0 : (sumProgress / total);

      final int progressInt =
          specificProgress ?? (overallProgress * 100).toInt();

      // 2. Determine Title/Body based on priority
      String title = 'Upload Service';
      String body = '';

      if (uploading > 0) {
        title = failed > 0
            ? 'Upload Issue ⚠️ ($progressInt%)'
            : 'Uploading Content ($progressInt%) 📤';
      } else if (isPaused) {
        title = 'Uploads Paused ($progressInt%) ⏸️';
        body = 'All uploads are currently on hold.';
        if (failed > 0) body += " • $failed Failed ⚠️";
      } else if (failed > 0) {
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
            icon: '@mipmap/ic_launcher',
            ongoing: uploading > 0 || isPaused || failed > 0,
            showProgress: uploading > 0 || isPaused,
            maxProgress: 100,
            progress: progressInt,
            priority: (uploading > 0 || isPaused || failed > 0)
                ? Priority.high
                : Priority.low,
            importance: (uploading > 0 || isPaused || failed > 0)
                ? Importance.high
                : Importance.low,
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

        // Throttling: Update UI every 100ms (Ultra-High responsiveness)
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastUpdate = lastUiUpdates[taskId] ?? 0;

        if (now - lastUpdate > 100 || progress >= 1.0) {
          lastUiUpdates[taskId] = now;
          broadcastQueue();

          // Update Notification smoothly every 800ms (Battery friendly)
          final lastNotif = lastUiUpdates['__notification__'] ?? 0;
          if (now - lastNotif > 800) {
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

      // Check for User in Background Isolate
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        LoggerService.info("Auth Found in Background: ${user.email}", tag: 'BG_SERVICE');
      } else {
        LoggerService.warning("Auth NOT Found in Background. Firestore writes might fail.", tag: 'BG_SERVICE');
      }

      // Load Config Keys
      await ConfigService().initialize();
      LoggerService.info(
        "Config Loaded. Storage Key Length: ${ConfigService().bunnyStorageKey.length}, Stream Key Length: ${ConfigService().bunnyStreamKey.length}",
        tag: 'BG_SERVICE',
      );

      // Re-initialize Uploaders with real keys
      tusUploader = TusUploader(
        apiKey: ConfigService().bunnyStreamKey,
        libraryId: ConfigService().bunnyLibraryId,
        videoId: '',
      );

      depsReady = true;
      LoggerService.success("Background dependencies initialized successfully.", tag: 'BG_SERVICE');
    } catch (e, stack) {
      LoggerService.error("Dependency Init Failed: $e\n$stack", tag: 'BG_SERVICE');
    }
  }

  // Define _triggerProcessing here...
  void triggerProcessing() async {
    if (isProcessing) return;
    if (!depsReady) {
      LoggerService.info(
        "Waiting for dependencies before starting engine...",
        tag: 'BG_SERVICE',
      );
      await initDeps();
    }
    isProcessing = true;

    LoggerService.info("Engine Loop Started", tag: 'BG_SERVICE');
    final Connectivity connectivity = Connectivity();

    while (true) {
      // 1. QUICK CONNECTIVITY CHECK
      bool hasNoInternet = false;
      List<ConnectivityResult> connectivityResults = [];
      try {
        connectivityResults = await connectivity.checkConnectivity();
        hasNoInternet = connectivityResults.contains(ConnectivityResult.none);
      } catch (e) {
        LoggerService.warning("Network check failed: $e", tag: 'BG_SERVICE');
      }

      if (hasNoInternet) {
        LoggerService.info(
          "No Internet. Idle check (5s)...",
          tag: 'BG_SERVICE',
        );
        await updateNotification("Waiting for internet... 📡", null);
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(seconds: 1));
          if (!isProcessing) return;
        }
        continue;
      }

      // --- 🚀 DYNAMIC SETTINGS BASED ON NETWORK SPEED ---
      int currentMaxConcurrent = 1;
      int currentTusChunkSize =
          1 * 1024 * 1024; // 1MB for ultra-granular commits & stability

      if (connectivityResults.contains(ConnectivityResult.wifi) ||
          connectivityResults.contains(ConnectivityResult.ethernet)) {
        currentMaxConcurrent = 3;
        currentTusChunkSize = 2 * 1024 * 1024; // 2MB for WiFi (Smooth + Fast)
        LoggerService.info(
          "WiFi/Ethernet Detected. Using 2MB chunks and 3 concurrent uploads.",
          tag: 'BG_SERVICE',
        );
      } else if (connectivityResults.contains(ConnectivityResult.mobile)) {
        currentMaxConcurrent = 2;
        currentTusChunkSize = 1 * 1024 * 1024; // 1MB for Mobile (Safe)
      } else {
        currentMaxConcurrent = 1;
        currentTusChunkSize = 512 * 1024; // 512KB fallback for very slow nets
      }

      // Check if service was asked to stop via flag (optional)

      // 2. MASTER PAUSE (DECOUPLED)
      // We removed the 'if (_isPaused) continue' to allow individual tasks to resume
      // even if the master toggle is in 'Paused' state. Master toggle now acts as a batch command.

      // 3. FRESH COUNTS
      final pendingCount = queue
          .where((t) => t['status'] == 'pending' && t['paused'] != true)
          .length;
      final activeCount = activeUploads.length;

      if (pendingCount == 0 && activeCount == 0) {
        // Check if everything is either completed or paused
        final bool allDoneOrPaused = queue.every(
          (t) => t['status'] == 'completed' || t['paused'] == true,
        );
        final bool hasFailedTasks = queue.any((t) => t['status'] == 'failed');

        if (allDoneOrPaused && queue.isNotEmpty) {
          final bool allCompleted = queue.every(
            (t) => t['status'] == 'completed',
          );
          if (allCompleted) {
            LoggerService.info(
              "Every single task completed. Finalizing...",
              tag: 'BG_SERVICE',
            );
            bool isTargetPublished = false;
            try {
              final String? cJson = prefs.getString(kPendingCourseKey);
              if (cJson != null) {
                final data = jsonDecode(cJson);
                isTargetPublished = data['isPublished'] ?? false;
              }
            } catch (_) {}

            await _finalizeCourseIfPending(service, queue, isPaused);
            await _finalizeUpdateIfPending(service, queue, isPaused);

            final msg = isTargetPublished
                ? "Course Published Successfully! ✅"
                : "Course Uploaded Successfully (Admin Side)! ✅";
            await updateNotification(msg, 100);
          } else {
            LoggerService.info(
              "Remaining tasks are PAUSED. Waiting 10s before sleep...",
              tag: 'BG_SERVICE',
            );
            await updateNotification("Uploads Paused ⏸️", null);
          }

          // 1. Release the lock so new triggers can wake the engine instantly
          isProcessing = false;

          LoggerService.info(
            "Tasks are PAUSED. Idle grace period (5s)...",
            tag: 'BG_SERVICE',
          );
          for (int i = 0; i < 5; i++) {
            await Future.delayed(const Duration(seconds: 1));
            // Check if someone else woke up the engine
            if (isProcessing) {
              LoggerService.info(
                "Engine woken up by another trigger! Stopping this idle loop.",
                tag: 'BG_SERVICE',
              );
              return;
            }
            final quickCheck = queue
                .where((t) => t['status'] == 'pending' && t['paused'] != true)
                .length;
            if (quickCheck > 0 || activeUploads.isNotEmpty) {
              LoggerService.info(
                "Instant wake-up detected! Re-triggering...",
                tag: 'BG_SERVICE',
              );
              triggerProcessing();
              return;
            }
          }

          service.invoke('all_completed');
          LoggerService.info(
            "Engine going to sleep (stopSelf).",
            tag: 'BG_SERVICE',
          );
          // service.stopSelf(); // Disabled for debugging
          return;
        }

        if (hasFailedTasks) {
          isProcessing = false; // Release lock for manual intervention
          LoggerService.info(
            "Actionable tasks 0, but FAILED tasks exist. Idle check (15s)...",
            tag: 'BG_SERVICE',
          );
          for (int i = 0; i < 15; i++) {
            await Future.delayed(const Duration(seconds: 1));
            if (isProcessing) return;
            final quickCheck = queue
                .where((t) => t['status'] == 'pending' && t['paused'] != true)
                .length;
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
          if (queue
              .where((t) => t['status'] == 'pending' && t['paused'] != true)
              .isNotEmpty) {
            triggerProcessing();
            return;
          }
        }

        if (queue.isEmpty) {
          LoggerService.info(
            "Queue empty. Syncing and Stopping.",
            tag: 'BG_SERVICE',
          );
          await updateNotification("Ready for tasks 🚀", null);
          service.invoke('update', {'queue': queue, 'isPaused': isPaused});
          isProcessing = false;
          await Future.delayed(const Duration(milliseconds: 500));
          return;
        }
        continue;
      }

      // 3. SLOT FILLING
      bool slotFilled = false;
      if (activeUploads.length < currentMaxConcurrent) {
        // Re-scan for next task
        final int nextIndex = queue.indexWhere(
          (t) =>
              t['status'] == 'pending' &&
              t['paused'] != true &&
              (t['retryAt'] == null ||
                  DateTime.now().isAfter(DateTime.parse(t['retryAt']))),
        );

        if (nextIndex != -1) {
          final task = queue[nextIndex];
          final String taskId = task['taskId'] ?? task['id'];
          LoggerService.info("Dispatching Task: $taskId", tag: 'BG_SERVICE');

          task['status'] = 'uploading';
          queue[nextIndex] = task;
          await saveQueue(); // Sync status change
          service.invoke('update', {'queue': queue, 'isPaused': isPaused});

          final cancelToken = CancelToken();
          activeUploads[taskId] = cancelToken;
          slotFilled = true;

          // Check File Type
          final String pathLower = task['filePath'].toString().toLowerCase();
          final bool isVideo =
              pathLower.endsWith('.mp4') ||
              pathLower.endsWith('.mov') ||
              pathLower.endsWith('.mkv') ||
              pathLower.endsWith('.avi');

          Future<String> uploadFuture;

          if (isVideo) {
            // TUS for Videos (Stream)
            uploadFuture = tusUploader
                .upload(
                  File(task['filePath']),
                  onProgress: (sent, total) =>
                      handleProgress(sent, total, taskId),
                  cancelToken: cancelToken,
                  chunkSize: currentTusChunkSize,
                )
                .then((videoId) {
                  // TUS returns Video ID. Construct Playback URL.
                  return "https://iframe.mediadelivery.net/play/${tusUploader.libraryId}/$videoId";
                });
          } else {
            // Standard Storage for Images/PDFs
            uploadFuture = bunnyService.uploadFile(
              filePath: task['filePath'],
              remotePath:
                  task['remotePath'], // Uses the actual path structure for storage
              onProgress: (sent, total) => handleProgress(sent, total, taskId),
              cancelToken: cancelToken,
            );
          }

          // Execute Upload
          unawaited(() async {
            try {
              final resultUrl = await uploadFuture;
              LoggerService.success(
                "Upload Success: $resultUrl",
                tag: 'BG_SERVICE',
              );

              final idx = queue.indexWhere(
                (t) => (t['taskId'] ?? t['id']) == taskId,
              );
              if (idx != -1) {
                queue[idx]['status'] = 'completed';
                queue[idx]['progress'] = 1.0;
                queue[idx]['url'] = resultUrl;
                // Ensure bytes are synced on completion
                if (queue[idx]['totalBytes'] != null) {
                  queue[idx]['uploadedBytes'] = queue[idx]['totalBytes'];
                }
                await saveQueue();
                service.invoke('update', {
                  'queue': queue,
                  'isPaused': isPaused,
                });
                service.invoke('task_completed', {'taskId': taskId});
              }
            } catch (e) {
              if (e is DioException && e.type == DioExceptionType.cancel) {
                LoggerService.warning(
                  "Task Cancelled: $taskId",
                  tag: 'BG_SERVICE',
                );
              } else {
                LoggerService.error(
                  "Upload Failed for $taskId: $e",
                  tag: 'BG_SERVICE',
                );
                final idx = queue.indexWhere(
                  (t) => (t['taskId'] ?? t['id']) == taskId,
                );
                if (idx != -1) {
                  queue[idx]['status'] = 'failed';
                  queue[idx]['error'] = e.toString();
                  // Retry Logic
                  final int retries = (queue[idx]['retries'] ?? 0) + 1;
                   queue[idx]['retries'] = retries;
                  if (retries <= 3) {
                    final retryDelay = Duration(
                      seconds: math.pow(2, retries).toInt() * 5,
                    );
                    queue[idx]['retryAt'] = DateTime.now()
                        .add(retryDelay)
                        .toIso8601String();
                    queue[idx]['status'] = 'pending';
                    LoggerService.warning(
                      "Scheduling Retry #$retries",
                      tag: 'BG_SERVICE',
                    );
                  }
                  await saveQueue();
                  service.invoke('update', {
                    'queue': queue,
                    'isPaused': isPaused,
                  });
                  service.invoke('upload_error', {
                    'taskId': taskId,
                    'error': e.toString(),
                  });
                }
              }
            } finally {
              activeUploads.remove(taskId);
            }
          }());

          // Safety breather to prevent battery-draining CPU spike
          await Future.delayed(const Duration(milliseconds: 200));
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
    service.invoke('service_ready'); // Re-ack if UI asks
    service.invoke('update', {'queue': queue, 'isPaused': isPaused});
    LoggerService.info("Status update sent to UI", tag: 'BG_SERVICE');
  });

  service.on('submit_course').listen((event) async {
    if (event == null) return;
    LoggerService.info(
      "Received 'submit_course' event from UI",
      tag: 'BG_SERVICE',
    );

    Map<String, dynamic> finalEvent = event;

    // 🔥 NEW: Optimized Metadata Loading (File-based)
    if (event.containsKey('metadataPath')) {
      final String path = event['metadataPath'];
      LoggerService.info("Reading Metadata File: $path", tag: 'BG_SERVICE');
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          LoggerService.info(
            "Metadata File Read Success. Size: ${content.length} chars",
            tag: 'BG_SERVICE',
          );
          finalEvent = jsonDecode(content);

          // Cleanup the temp file
          await file.delete();
          LoggerService.info("Metadata Temp File Deleted", tag: 'BG_SERVICE');

          // 🔥 NEW: Inject API keys if passed from UI
          if (finalEvent.containsKey('bunnyKeys')) {
            final keys = finalEvent['bunnyKeys'];
            ConfigService().setupKeys(
              storageKey: keys['storageKey'] ?? '',
              streamKey: keys['streamKey'] ?? '',
              libraryId: keys['libraryId'] ?? '',
            );
          }
        } else {
          LoggerService.error(
            "Metadata File NOT FOUND at $path",
            tag: 'BG_SERVICE',
          );
          return;
        }
      } catch (e) {
        LoggerService.error(
          "Failed to read metadata file: $e",
          tag: 'BG_SERVICE',
        );
        return;
      }
    }

    // 1. Save Course Metadata
    final courseData = finalEvent['course'];
    final String courseTitle = courseData?['title'] ?? 'Unknown Course';
    LoggerService.info(
      "Saving metadata for course: $courseTitle",
      tag: 'BG_SERVICE',
    );
    await prefs.setString(kPendingCourseKey, jsonEncode(courseData));

    // 2. Add Files to Queue
    final List<dynamic> items = finalEvent['files'] ?? [];
    LoggerService.info(
      "Adding ${items.length} files to upload queue",
      tag: 'BG_SERVICE',
    );

    int addedCount = 0;
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
        addedCount++;
      } else {
        LoggerService.warning(
          "Skipping duplicate task: $filePath",
          tag: 'BG_SERVICE',
        );
      }
    }

    LoggerService.success(
      "Queue Updated. Added $addedCount new tasks. Total Queue Size: ${queue.length}",
      tag: 'BG_SERVICE',
    );

    await saveQueue();

    // 3. Start
    LoggerService.info("Triggering Processing Loop...", tag: 'BG_SERVICE');
    triggerProcessing();
    unawaited(updateNotification("Course Creation Started", 0));
  });

  service.on('update_course').listen((event) async {
    if (event == null) return;

    Map<String, dynamic> finalEvent = event;

    // 🔥 NEW: Optimized Metadata Loading (File-based)
    if (event.containsKey('metadataPath')) {
      try {
        final file = File(event['metadataPath']);
        if (await file.exists()) {
          final content = await file.readAsString();
          finalEvent = jsonDecode(content);
          await file.delete();

          // 🔥 NEW: Inject API keys
          if (finalEvent.containsKey('bunnyKeys')) {
            final keys = finalEvent['bunnyKeys'];
            ConfigService().setupKeys(
              storageKey: keys['storageKey'] ?? '',
              streamKey: keys['streamKey'] ?? '',
              libraryId: keys['libraryId'] ?? '',
            );
          }
        }
      } catch (e) {
        LoggerService.error(
          "Failed to read metadata file (Update): $e",
          tag: 'BG_SERVICE',
        );
        return;
      }
    }

    final updateData = finalEvent['updateData'];
    final String courseId = finalEvent['courseId'];
    updateData['id'] = courseId; // Ensure ID is present

    LoggerService.info(
      "Saving update metadata for course: $courseId",
      tag: 'BG_SERVICE',
    );
    await prefs.setString(kPendingUpdateCourseKey, jsonEncode(updateData));

    // 2. Add Files to Queue
    final List<dynamic> items = finalEvent['files'] ?? [];
    LoggerService.info(
      "Adding ${items.length} files to queue (Update)",
      tag: 'BG_SERVICE',
    );

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
      LoggerService.warning(
        "Skipped adding duplicate task via add_task: $filePath",
        tag: 'BG_SERVICE',
      );
    }
  });

  service.on('cancel_all').listen((event) async {
    LoggerService.info(
      "CANCEL ALL: Starting destructive cleanup...",
      tag: 'BG_SERVICE',
    );

    // 1. Cancel Active Transfers
    for (var taskId in activeUploads.keys.toList()) {
      LoggerService.info(
        "Cancelling task $taskId due to 'cancel_all'",
        tag: 'BG_SERVICE',
      );
      activeUploads[taskId]?.cancel('User cancelled all uploads');
    }
    activeUploads.clear();

    // 2. DELETE UPLOADED FILES FROM SERVER (Aggressive Status-Independent)
    try {
      for (var task in queue) {
        final String? assetUrl = task['url'];
        final String? remotePath = task['remotePath'];
        final String taskId = task['taskId'] ?? task['id'] ?? 'unknown';

        if (assetUrl != null &&
            assetUrl.isNotEmpty &&
            !assetUrl.startsWith('http')) {
          // Video record cleanup
          LoggerService.info(
            "Bulk Cleanup: Deleting Video ID $assetUrl for task $taskId",
            tag: 'BG_SERVICE',
          );
          await bunnyService.deleteVideo(
            libraryId: ConfigService().bunnyLibraryId,
            videoId: assetUrl,
            apiKey: ConfigService().bunnyStreamKey,
          );
        } else if (remotePath != null && remotePath.isNotEmpty) {
          // Storage file cleanup
          LoggerService.info(
            "Bulk Cleanup: Deleting Storage Path $remotePath for task $taskId",
            tag: 'BG_SERVICE',
          );
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

    // 4. Clear Course Metadata & Global Lock
    await prefs.remove(kPendingCourseKey);
    await prefs.remove(kPendingUpdateCourseKey);
    await prefs.remove(kQueueKey);

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
    service.invoke('service_reset_complete');
  });

  service.on('skip_and_finalize').listen((event) async {
    LoggerService.warning(
      "SKIP_AND_FINALIZE triggered. Finalizing without failed items.",
      tag: 'BG_SERVICE',
    );
    // We pass forceSkip: true to allow finalization even if failed tasks are detected in disk queue
    await _finalizeCourseIfPending(service, queue, isPaused, forceSkip: true);
    await _finalizeUpdateIfPending(service, queue, isPaused, forceSkip: true);
  });

  service.on('pause').listen((event) async {
    LoggerService.info(
      "Global PAUSE received. Data: $event",
      tag: 'BG_SERVICE',
    );
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
    LoggerService.info(
      "Global RESUME received. Data: $event",
      tag: 'BG_SERVICE',
    );
    isPaused = false;
    for (var task in queue) {
      task['paused'] = false;
      // Removed progress = 0.0 to prevent jumping
    }
    await saveQueue();
    await updateNotification(null, null);
    triggerProcessing();
  });

  service.on('pause_task').listen((event) async {
    if (event == null || event['taskId'] == null) return;
    final String taskId = event['taskId'];
    LoggerService.info(
      "SERVICE RECEIVED pause_task: $taskId",
      tag: 'BG_SERVICE',
    );
    final taskIndex = queue.indexWhere(
      (t) => (t['taskId'] ?? t['id']) == taskId,
    );
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
    LoggerService.info(
      "SERVICE RECEIVED resume_task: $taskId",
      tag: 'BG_SERVICE',
    );
    final taskIndex = queue.indexWhere(
      (t) => (t['taskId'] ?? t['id']) == taskId,
    );
    if (taskIndex != -1) {
      queue[taskIndex]['paused'] = false;
      queue[taskIndex]['retries'] = 0;
      queue[taskIndex]['retryAt'] = null;
      if (queue[taskIndex]['status'] == 'failed' ||
          queue[taskIndex]['status'] == 'uploading') {
        queue[taskIndex]['status'] = 'pending';
        // Note: We NOT reset progress to 0 here to keep the bar stable during resume
      }
      await saveQueue();
      await updateNotification(null, null);
      triggerProcessing();
    }
  });

  service.on('delete_task').listen((event) async {
    if (event == null || event['taskId'] == null) return;
    final taskId = event['taskId'];
    LoggerService.info(
      "SERVICE RECEIVED delete_task: $taskId",
      tag: 'BG_SERVICE',
    );

    // 1. Cancel active upload
    if (activeUploads.containsKey(taskId)) {
      LoggerService.warning(
        "Cancelling active upload for $taskId before delete",
        tag: 'BG_SERVICE',
      );
      activeUploads[taskId]?.cancel('User deleted task');
      activeUploads.remove(taskId);
    }

    final taskIndex = queue.indexWhere(
      (t) => (t['taskId'] ?? t['id']) == taskId,
    );
    if (taskIndex != -1) {
      final task = queue[taskIndex];
      final String? remotePath = task['remotePath'];
      final String? assetUrl = task['url'];

      // 2. Delete from Server
      try {
        bool deletedFromServer = false;
        if (assetUrl != null &&
            assetUrl.isNotEmpty &&
            !assetUrl.startsWith('http')) {
          LoggerService.info(
            "Deleting Video ID $assetUrl from Bunny Stream...",
            tag: 'BG_SERVICE',
          );
          deletedFromServer = await bunnyService.deleteVideo(
            libraryId: ConfigService().bunnyLibraryId,
            videoId: assetUrl,
            apiKey: ConfigService().bunnyStreamKey,
          );
        } else if (remotePath != null && remotePath.isNotEmpty) {
          LoggerService.info(
            "Deleting Storage Path $remotePath from Bunny...",
            tag: 'BG_SERVICE',
          );
          deletedFromServer = await bunnyService.deleteFile(remotePath);
        }
        if (deletedFromServer) {
          LoggerService.success(
            "Server Cleanup SUCCESS for $taskId",
            tag: 'BG_SERVICE',
          );
        }
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
        } catch (e) {
          LoggerService.warning(
            "Local file delete error: $e",
            tag: 'BG_SERVICE',
          );
        }
      }

      if (queue.isEmpty) {
        LoggerService.info(
          "Queue empty after delete. Clearing pending course key.",
          tag: 'BG_SERVICE',
        );
        await prefs.remove(kPendingCourseKey);
      }

      await saveQueue();
      await updateNotification(null, null);
      service.invoke('update', {'queue': queue, 'isPaused': isPaused});
      triggerProcessing();
    } else {
      LoggerService.warning(
        "Task not found in queue for deletion: $taskId",
        tag: 'BG_SERVICE',
      );
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
  await prefs.setString(
    'last_bg_service_uri',
    info.serverUri?.toString() ?? '',
  );
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
  isPaused = prefs.getBool(kServiceStateKey) ?? false;

  service.invoke('update', {'queue': queue, 'isPaused': isPaused});

  // Wait a small bit for deps before first trigger
  Future.delayed(const Duration(seconds: 1), () {
    if (queue.isNotEmpty) triggerProcessing();
  });
}

// --- HELPER: Finalize Course ---
Future<void> _finalizeCourseIfPending(
  ServiceInstance service,
  List<Map<String, dynamic>> queue,
  bool isPaused, {
  bool forceSkip = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final String? courseJson = prefs.getString(kPendingCourseKey);

  if (courseJson == null) return; // No pending course

  final queueJson = prefs.getString(kQueueKey);
  if (queueJson == null) return;
  final List<Map<String, dynamic>> diskQueue = List<Map<String, dynamic>>.from(
    jsonDecode(queueJson),
  );

  // Check if any failed
  if (!forceSkip && diskQueue.any((t) => t['status'] == 'failed')) {
    LoggerService.warning(
      "Finalization Halted: Queue has failed items",
      tag: 'BG_SERVICE',
    );

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.show(
      id: kServiceNotificationId + 5,
      title: 'Finalization Paused ⚠️',
      body:
          'Some files failed to upload. Fix them to complete course creation.',
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
    return;
  }

  final urlMap = <String, String>{};
  for (var task in diskQueue) {
    if (task['status'] == 'completed' &&
        task['url'] != null &&
        task['filePath'] != null) {
      urlMap[task['filePath']] = task['url'];
    }
  }

  try {
    final Map<String, dynamic> courseData = jsonDecode(courseJson);

    if (urlMap.containsKey(courseData['thumbnailUrl'])) {
      courseData['thumbnailUrl'] = urlMap[courseData['thumbnailUrl']];
    }
    if (urlMap.containsKey(courseData['certificateUrl1'])) {
      courseData['certificateUrl1'] = urlMap[courseData['certificateUrl1']];
    }
    if (urlMap.containsKey(courseData['certificateUrl2'])) {
      courseData['certificateUrl2'] = urlMap[courseData['certificateUrl2']];
    }

    final List<dynamic> contents = courseData['contents'] ?? [];
    _updateContentPaths(contents, urlMap);
    if (forceSkip) _removeLocalItems(contents);
    courseData['contents'] = contents;
    courseData['totalVideos'] = _countVideos(contents);

    bool hasLocalPaths = false;
    if (courseData['thumbnailUrl'] != null &&
        courseData['thumbnailUrl'].toString().startsWith('/')) {
      hasLocalPaths = true;
    }
    if (!hasLocalPaths) hasLocalPaths = _checkForLocalPaths(contents);

    if (hasLocalPaths && !forceSkip) {
      LoggerService.error(
        "SAFETY HALT: Course still contains local paths!",
        tag: 'BG_SERVICE',
      );

      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.show(
        id: kServiceNotificationId + 2,
        title: 'Upload Failed ⚠️',
        body:
            'Course not published: Some files could not be linked. Please try again.',
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
      return;
    }

    final bool isTargetPublished = courseData['isPublished'] ?? false;
    courseData['status'] = isTargetPublished ? 'active' : 'draft';

    // 🔥 Use Server Timestamp for new records to avoid local clock issues (e.g. 2026 error)
    if (!courseData.containsKey('createdAt') || courseData['createdAt'] == null) {
      courseData['createdAt'] = FieldValue.serverTimestamp();
    }
    // If it's an update and already has a string date, we can keep it or let it be.
    // For now, let's ensure new ones get Server Time.

    final String? courseId = courseData['id'];

    try {
      final String projectId = Firebase.app().options.projectId;
      LoggerService.info(
        "Target Firestore Project: $projectId",
        tag: 'BG_SERVICE',
      );

      if (courseId != null && courseId.isNotEmpty) {
        LoggerService.info(
          "Setting Course Document: $courseId",
          tag: 'BG_SERVICE',
        );
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseId)
            .set(courseData);
      } else {
        LoggerService.info(
          "Adding New Course Document (Auto ID)",
          tag: 'BG_SERVICE',
        );
        await FirebaseFirestore.instance.collection('courses').add(courseData);
      }
      LoggerService.success("Firestore Write SUCCESS ✅", tag: 'BG_SERVICE');
    } catch (e) {
      LoggerService.error("FIRESTORE WRITE FAILED ❌: $e", tag: 'BG_SERVICE');

      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.show(
        id: kServiceNotificationId + 10,
        title: 'Database Error ❌',
        body: 'Upload finished but could not save course: $e',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            kAlertNotificationChannelId,
            'Upload Errors',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
      // Re-throw to prevent queue cleanup
      throw Exception("Firestore Write Failed: $e");
    }

    try {
      for (var localPath in urlMap.keys) {
        if (localPath.contains('pending_uploads')) {
          final f = File(localPath);
          if (await f.exists()) await f.delete();
        }
      }
    } catch (_) {}

    await prefs.remove(kPendingCourseKey);
    await prefs.remove(kQueueKey);
    queue.clear();
    service.invoke('update', {'queue': queue, 'isPaused': isPaused});

    // Notify
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    final String alertTitle = isTargetPublished
        ? 'Course Published! 🚀'
        : 'Upload Successful! ✅';
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

    // Explicitly signal completion to UI
    service.invoke('all_completed');
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
      LoggerService.info(
        "Metadata Cleanup: Removing $filePath from contents list",
        tag: 'BG_SERVICE',
      );
      contents.removeAt(i);
      continue;
    }

    // If it's a thumbnail reference in an item, just clear it
    if (item['thumbnail'] == filePath) {
      LoggerService.info(
        "Metadata Cleanup: Clearing thumbnail reference for $filePath",
        tag: 'BG_SERVICE',
      );
      item['thumbnail'] = null;
    }

    // If it's a folder, recurse
    if (item['type'] == 'folder' &&
        item['contents'] != null &&
        item['contents'] is List) {
      _removeFileFromContentsRecursive(item['contents'], filePath);
    }
  }
}

bool _checkForLocalPaths(List<dynamic> contents) {
  for (var item in contents) {
    if (item is! Map) continue;

    // Check main path
    if (item['path'] != null && item['path'].toString().startsWith('/')) {
      LoggerService.warning(
        "Found local path in content: ${item['name']}",
        tag: 'BG_SERVICE',
      );
      return true;
    }

    // Check thumbnail if exists
    if (item['thumbnail'] != null &&
        item['thumbnail'].toString().startsWith('/')) {
      LoggerService.warning(
        "Found local thumbnail in content: ${item['name']}",
        tag: 'BG_SERVICE',
      );
      return true;
    }

    // Recurse for folders
    if (item['type'] == 'folder' && item['contents'] != null) {
      if (_checkForLocalPaths(item['contents'])) return true;
    }
  }
  return false;
}

// --- HELPER: Finalize Update ---
Future<void> _finalizeUpdateIfPending(
  ServiceInstance service,
  List<Map<String, dynamic>> queue,
  bool isPaused, {
  bool forceSkip = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final String? updateJson = prefs.getString(kPendingUpdateCourseKey);

  if (updateJson == null) return;

  final queueJson = prefs.getString(kQueueKey);
  if (queueJson == null) return;
  final List<Map<String, dynamic>> diskQueue = List<Map<String, dynamic>>.from(
    jsonDecode(queueJson),
  );

  if (!forceSkip && diskQueue.any((t) => t['status'] == 'failed')) return;

  final urlMap = <String, String>{};
  for (var task in diskQueue) {
    if (task['status'] == 'completed' &&
        task['url'] != null &&
        task['filePath'] != null) {
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

    final bool isTargetPublished = updateData['isPublished'] ?? false;
    updateData['status'] = isTargetPublished ? 'active' : 'draft';

    if (updateData.containsKey('contents')) {
      final List<dynamic> contents = updateData['contents'] ?? [];
      _updateContentPaths(contents, urlMap);
      if (forceSkip) _removeLocalItems(contents);
      updateData['contents'] = contents;
      updateData['totalVideos'] = _countVideos(contents);
    }

    updateData.remove('id');
    // Firestore Write
    try {
      final String projectId = Firebase.app().options.projectId;
      LoggerService.info(
        "Target Firestore Project: $projectId",
        tag: 'BG_SERVICE',
      );
      LoggerService.info(
        "Updating Course Document: $courseId",
        tag: 'BG_SERVICE',
      );
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(courseId)
          .update(updateData);
      LoggerService.success("Firestore Update SUCCESS ✅", tag: 'BG_SERVICE');
    } catch (e) {
      LoggerService.error("FIRESTORE UPDATE FAILED ❌: $e", tag: 'BG_SERVICE');

      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.show(
        id: kServiceNotificationId + 10,
        title: 'Database Error ❌',
        body: 'Update finished but could not save changes to database: $e',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            kAlertNotificationChannelId,
            'Upload Errors',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
      // Re-throw to prevent queue cleanup if DB write failed
      throw Exception("Firestore Update Failed: $e");
    }

    try {
      for (var localPath in urlMap.keys) {
        if (localPath.contains('pending_uploads')) {
          final f = File(localPath);
          if (await f.exists()) await f.delete();
        }
      }
    } catch (_) {}

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

    // Explicitly signal completion to UI
    service.invoke('all_completed');
  } catch (e) {
    LoggerService.error("Finalization (Update) Error: $e", tag: 'BG_SERVICE');
  }
}

void _removeLocalItems(List<dynamic> items) {
  for (var item in items) {
    if (item is! Map) continue;
    if (item['type'] == 'folder' && item['contents'] != null) {
      _removeLocalItems(item['contents'] as List);
    }
  }
  items.removeWhere((item) {
    if (item is! Map) return false;
    if (item['type'] == 'folder') return false;
    final path = item['path']?.toString() ?? '';
    final isLocal = item['isLocal'] == true;
    return isLocal && (path.startsWith('/') || path.isEmpty);
  });
}

int _countVideos(List<dynamic> items) {
  int count = 0;
  void countRecursive(dynamic item) {
    if (item is! Map) return;
    if (item['type'] == 'video') count++;
    if (item['type'] == 'folder' && item['contents'] != null) {
      for (var sub in item['contents']) {
        countRecursive(sub);
      }
    }
  }

  for (var item in items) {
    countRecursive(item);
  }
  return count;
}
