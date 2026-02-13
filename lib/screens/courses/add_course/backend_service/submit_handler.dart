import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../models/course_model.dart';
import '../local_logic/state_manager.dart';
import '../local_logic/validation.dart';
import '../../../../services/config_service.dart';
import '../../../../screens/uploads/upload_progress_screen.dart';
import '../../../../services/logger_service.dart';
import '../local_logic/draft_manager.dart';
import '../../../../services/security_service.dart';

class SubmitHandler {
  final CourseStateManager state;
  final ValidationLogic validation;
  final DraftManager draftManager;

  SubmitHandler(this.state, this.validation, this.draftManager);

  Future<void> submitCourse(
    BuildContext context,
    Function(String) showWarning,
  ) async {
    // 1. Instant Haptic Feedback for physical connection
    HapticFeedback.mediumImpact();

    if (!validation.validateAllFields(onValidationError: showWarning)) return;
    if (state.courseContents.isEmpty) {
      state.courseContentError = true;
      state.updateState();
      showWarning('Please add at least one content to the course');
      state.currentStep = 2;
      state.pageController.jumpToPage(2);
      return;
    }

    if (!context.mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('pending_course_v1')) {
      if (context.mounted) _showInProcessDialog(context);
      return;
    }

    state.isLoading = true;
    state.isUploading = true;
    state.uploadTasks = [];
    state.updateState();

    LoggerService.info(
      "Starting Course Submission Process...",
      tag: 'SUBMIT_HANDLER',
    );

    try {
      await WakelockPlus.enable();
      await ConfigService().initialize();

      final String finalDesc = state.descController.text.trim();
      final int finalValidity = state.courseValidityDays == -1
          ? (int.tryParse(state.customValidityController.text) ?? 0)
          : state.courseValidityDays!;

      final appDir = await getApplicationDocumentsDirectory();
      final safeDir = Directory('${appDir.path}/upload_metadata');
      if (!safeDir.existsSync()) safeDir.createSync(recursive: true);

      final String docId =
          state.editingCourseId ??
          FirebaseFirestore.instance.collection('courses').doc().id;

      final draftCourse = CourseModel(
        id: docId,
        title: state.titleController.text.trim(),
        category: state.selectedCategory!,
        price: (double.tryParse(state.mrpController.text) ?? 0).round(),
        discountPrice: (double.tryParse(state.finalPriceController.text) ?? 0)
            .round(),
        description: finalDesc,
        thumbnailUrl:
            state.thumbnailImage?.path ?? state.currentThumbnailUrl ?? '',
        duration: finalValidity == 0
            ? 'Lifetime Access'
            : '$finalValidity Days',
        difficulty: state.difficulty!,
        enrolledStudents: state.originalCourse?.enrolledStudents ?? 0,
        rating: state.originalCourse?.rating ?? 0.0,
        totalVideos: _countVideos(state.courseContents),
        isPublished: state.isPublished,
        createdAt: state.originalCourse?.createdAt,
        courseValidityDays: finalValidity,
        hasCertificate: state.hasCertificate,
        certificateUrl1:
            state.certificate1File?.path ?? state.currentCertificate1Url,
        selectedCertificateSlot: 1,
        isOfflineDownloadEnabled: state.isOfflineDownloadEnabled,
        language: state.selectedLanguage!,
        courseMode: state.selectedCourseMode!,
        supportType: state.selectedSupportType!,
        whatsappNumber: state.whatsappController.text.trim(),
        isBigScreenEnabled: state.isBigScreenEnabled,
        websiteUrl: state.websiteUrlController.text.trim(),
        specialTag: state.specialTagController.text.trim(),
        specialTagColor: state.specialTagColor,
        isSpecialTagVisible: state.isSpecialTagVisible,
        specialTagDurationDays: state.specialTagDurationDays,
        bunnyCollectionId: state.bunnyCollectionId,
        contents: state.courseContents,
        highlights: state.highlightControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        faqs: state.faqControllers
            .map(
              (f) => {
                'question': f['q']!.text.trim(),
                'answer': f['a']!.text.trim(),
              },
            )
            .where((f) => f['question']!.isNotEmpty && f['answer']!.isNotEmpty)
            .toList(),
      );

      final sessionId =
          state.editingCourseId ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final List<Map<String, dynamic>> fileTasks = [];
      final Set<String> processedFilePaths = {};

      unawaited(draftManager.saveCourseDraft());

      if (state.thumbnailImage != null) {
        _addTask(
          fileTasks,
          processedFilePaths,
          state.thumbnailImage!.path,
          'courses/$sessionId/thumbnails/thumb_${path.basename(state.thumbnailImage!.path)}',
          'thumb',
        );
      }

      // Certificate Upload Logic
      if (state.hasCertificate && state.certificate1File != null) {
        _addTask(
          fileTasks,
          processedFilePaths,
          state.certificate1File!.path,
          'courses/$sessionId/certificates/cert1_${path.basename(state.certificate1File!.path)}',
          'cert1',
        );
      }

      int globalCounter = 0;
      void processItemRecursive(dynamic item) {
        if (item is! Map) return;
        final int currentIndex = globalCounter++;
        final String type = item['type'] ?? 'unknown';

        bool isActuallyLocal(dynamic p) {
          if (p == null || p is! String || p.isEmpty) return false;
          if (p.startsWith('http') || p.startsWith('https')) return false;
          return p.startsWith('/') ||
              p.contains(':\\') ||
              p.contains('/cache/') ||
              p.contains('\\cache\\');
        }

        // 1. Process File Task
        final String? contentPath = item['path']?.toString();
        // Robust Check: Trust URL check over isLocal flag
        // If it's a URL, it is definitely NOT local.
        final bool isUrl =
            contentPath != null &&
            (contentPath.startsWith('http') || contentPath.startsWith('https'));

        // 🔥 FIX: A video is ONLY local if it doesn't have a URL and is marked as local
        final bool isLocal =
            !isUrl && (item['isLocal'] == true || isActuallyLocal(contentPath));

        if ((type == 'video' || type == 'pdf' || type == 'image') && isLocal) {
          final filePath = item['path'];
          if (filePath != null && filePath is String && filePath.isNotEmpty) {
            String folder = 'others';
            if (type == 'video') {
              folder = 'videos';
            } else if (type == 'pdf') {
              folder = 'pdfs';
            } else if (type == 'image') {
              folder = 'images';
            }

            final String ext = path.extension(filePath);
            final String safeName = (item['name'] ?? 'file')
                .toString()
                .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
            final uniqueName = '${currentIndex}_$safeName$ext';

            _addTask(
              fileTasks,
              processedFilePaths,
              filePath,
              'courses/$sessionId/$folder/$uniqueName',
              filePath,
              thumbnail: (type == 'video' && item['thumbnail'] != null)
                  ? item['thumbnail']
                  : null,
            );
          }
        }

        // 2. Process Thumbnail Task (Standalone or Video Thumb)
        if (item['thumbnail'] != null && item['thumbnail'] is String) {
          final String thumbPath = item['thumbnail'];
          if (thumbPath.isNotEmpty &&
              !thumbPath.startsWith('http') &&
              (thumbPath.startsWith('/') || thumbPath.contains(':\\'))) {
            _addTask(
              fileTasks,
              processedFilePaths,
              thumbPath,
              'courses/$sessionId/thumbnails/thumb_${currentIndex}_${path.basename(thumbPath)}',
              thumbPath,
            );
          }
        }

        // 3. Recurse into Folders
        if (type == 'folder' &&
            item['contents'] != null &&
            item['contents'] is List) {
          for (var sub in item['contents']) {
            processItemRecursive(sub);
          }
        }
      }

      for (var item in state.courseContents) {
        processItemRecursive(item);
      }

      final service = FlutterBackgroundService();

      // Reliable Command Delivery
      bool commandDelivered = false;
      int retryCount = 0;
      const int maxRetries = 15;

      if (!await service.isRunning()) {
        await service.startService();
      }

      final String metadataFileName = 'course_metadata_$sessionId.json';
      final File metadataFile = File('${safeDir.path}/$metadataFileName');

      final Map<String, dynamic> payload = {};

      // Course Data
      final contentMap = draftCourse.toMap();
      _prepareMapForJson(contentMap);

      if (state.editingCourseId != null) {
        payload['updateData'] = contentMap;
        payload['updateData'].remove('id');
        payload['courseId'] = docId;
      } else {
        contentMap['id'] = docId;
        payload['course'] = contentMap;
      }

      payload['files'] = fileTasks;

      // API Keys
      final config = ConfigService();
      final sec = SecurityService();
      payload['bunnyKeys'] = {
        'enc': true,
        'storageKey': sec.encryptText(config.bunnyStorageKey),
        'streamKey': sec.encryptText(config.bunnyStreamKey),
        'libraryId': sec.encryptText(config.bunnyLibraryId),
      };

      LoggerService.info(
        "Writing metadata file: ${metadataFile.path}",
        tag: 'SUBMIT_HANDLER',
      );
      final rawJson = jsonEncode(payload);
      final encoded = base64Encode(utf8.encode(rawJson));
      await metadataFile.writeAsString(encoded);

      LoggerService.info(
        "Metadata Payload Ready. Sending command to Background Service...",
        tag: 'SUBMIT_HANDLER',
      );

      int delayMs = 100;
      while (!commandDelivered && retryCount < maxRetries) {
        if (state.editingCourseId != null) {
          service.invoke('update_course', {'metadataPath': metadataFile.path});
        } else {
          service.invoke('submit_course', {'metadataPath': metadataFile.path});
        }
        service.invoke('get_status');

        await Future.delayed(Duration(milliseconds: delayMs));

        final checkPrefs = await SharedPreferences.getInstance();
        final keyToCheck = state.editingCourseId != null
            ? 'pending_update_course_v1'
            : 'pending_course_v1';

        if (checkPrefs.containsKey(keyToCheck)) {
          commandDelivered = true;
          debugPrint("✅ SubmitHandler: Command delivered (via Metadata File)");
        }
        retryCount++;
        if (delayMs < 1600) {
          delayMs = delayMs * 2;
          if (delayMs > 1600) delayMs = 1600;
        }
      }

      await prefs.remove('course_creation_draft');
      // 🔥 FIX: Remove the specific course draft on successful submission start.
      // This ensures that after the background upload completes, the app
      // will fetch fresh data from the server instead of showing stale local draft data.
      if (state.editingCourseId != null) {
        final draftKey = 'course_draft_${state.editingCourseId}';
        await prefs.remove(draftKey);
        LoggerService.info(
          "Cleared local draft for course: ${state.editingCourseId}",
          tag: 'SUBMIT_HANDLER',
        );
      }
      state.resetAll();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.editingCourseId != null
                  ? 'Update Started in Background 🚀'
                  : 'Upload Started in Background 🚀',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        unawaited(
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const UploadProgressScreen()),
          ),
        );
      }
    } catch (e, stack) {
      LoggerService.error(
        "SUBMIT_HANDLER FAILED: $e\n$stack",
        tag: 'SUBMIT_HANDLER',
      );
      state.isLoading = false;
      state.isUploading = false;
      state.updateState();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      await WakelockPlus.disable();
    }
  }

  int _countVideos(List<dynamic> items) {
    int count = 0;
    void countRecursive(dynamic item) {
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

  void _showInProcessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Upload in Progress ⚠️"),
        content: const Text(
          "Another course is currently being uploaded in the background.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _addTask(
    List<Map<String, dynamic>> fileTasks,
    Set<String> processedFilePaths,
    String filePath,
    String remotePath,
    String id, {
    String? thumbnail,
  }) {
    if (processedFilePaths.add(filePath)) {
      fileTasks.add({
        'filePath': filePath,
        'remotePath': remotePath,
        'id': id,
        if (thumbnail != null) 'thumbnail': thumbnail,
      });
    }
  }

  void _prepareMapForJson(Map<String, dynamic> map) {
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        map['createdAt'] = (map['createdAt'] as Timestamp)
            .toDate()
            .toIso8601String();
      } else if (map['createdAt'] is DateTime) {
        map['createdAt'] = (map['createdAt'] as DateTime).toIso8601String();
      } else {
        map.remove('createdAt');
      }
    }
  }
}
