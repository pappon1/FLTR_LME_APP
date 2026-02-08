import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../models/course_model.dart';
import '../local_logic/state_manager.dart';
import '../local_logic/validation.dart';
import 'package:disk_space_2/disk_space_2.dart';
import '../../../../screens/uploads/upload_progress_screen.dart';

class SubmitHandler {
  final CourseStateManager state;
  final ValidationLogic validation;

  SubmitHandler(this.state, this.validation);

  Future<void> submitCourse(
    BuildContext context,
    Function(String) showWarning,
  ) async {
    if (!validation.validateAllFields(onValidationError: showWarning)) return;
    if (state.courseContents.isEmpty) {
      state.courseContentError = true;
      state.updateState();
      showWarning('Please add at least one content to the course');
      _jumpToStep(2);
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

    try {
      await WakelockPlus.enable();

      final String finalDesc = state.descController.text.trim();
      final int finalValidity = state.courseValidityDays == -1
          ? (int.tryParse(state.customValidityController.text) ?? 0)
          : state.courseValidityDays!;

      final appDir = await getApplicationDocumentsDirectory();
      final safeDir = Directory('${appDir.path}/pending_uploads');
      if (!safeDir.existsSync()) safeDir.createSync(recursive: true);

      final Map<String, String> copiedPathMap = {};

      // --- Point 7: Disk Space Check ---
      double totalSizeNeeded = 0;
      final List<File> filesToCopy = [];

      void calculateSizeRecursive(dynamic items) {
        for (var item in items) {
          final String type = item['type'];
          if ((type == 'video' || type == 'pdf' || type == 'image') &&
              item['isLocal'] == true) {
            final String? fPath = item['path'];
            if (fPath != null && fPath.isNotEmpty) {
              final file = File(fPath);
              if (file.existsSync()) {
                totalSizeNeeded += file.lengthSync();
                filesToCopy.add(file);
              }
            }
          }
          if (item['thumbnail'] != null && item['thumbnail'] is String) {
            final String tPath = item['thumbnail'];
            if (tPath.isNotEmpty && !tPath.startsWith('http')) {
              final file = File(tPath);
              if (file.existsSync()) {
                totalSizeNeeded += file.lengthSync();
                filesToCopy.add(file);
              }
            }
          }
          if (type == 'folder' && item['contents'] != null) {
            calculateSizeRecursive(item['contents']);
          }
        }
      }

      calculateSizeRecursive(state.courseContents);
      if (state.thumbnailImage != null)
        totalSizeNeeded += state.thumbnailImage!.lengthSync();
      if (state.certificate1File != null)
        totalSizeNeeded += state.certificate1File!.lengthSync();

      // Get free space (MB to Bytes)
      final double? freeSpaceMb = await DiskSpace.getFreeDiskSpace;
      if (freeSpaceMb != null) {
        final double freeSpaceBytes = freeSpaceMb * 1024 * 1024;
        if (freeSpaceBytes < (totalSizeNeeded * 1.2)) {
          // 20% buffer
          state.isLoading = false;
          state.isUploading = false;
          state.updateState();
          showWarning(
            'Low Disk Space! Need approx ${_formatBytes(totalSizeNeeded.toInt())} free.',
          );
          return;
        }
      }

      // --- Point 1: Preparation Progress ---
      int totalFiles = filesToCopy.length;
      if (state.thumbnailImage != null) totalFiles++;
      if (state.certificate1File != null) totalFiles++;

      int copiedCount = 0;
      void updatePrep(String msg) {
        state.preparationMessage = msg;
        state.preparationProgress = totalFiles > 0
            ? copiedCount / totalFiles
            : 1.0;
        state.updateState();
      }

      updatePrep("Preparing files...");

      Future<String> copyToSafe(String rawPath, String label) async {
        if (copiedPathMap.containsKey(rawPath)) return copiedPathMap[rawPath]!;
        final f = File(rawPath);
        if (!f.existsSync()) return rawPath;

        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(rawPath)}';
        final newPath = '${safeDir.path}/$filename';

        updatePrep("Copying $label...");
        await f.copy(newPath);

        copiedCount++;
        updatePrep("Copying $label...");

        copiedPathMap[rawPath] = newPath;
        return newPath;
      }

      // Processing Contents with sequence for better feedback
      // (Even if we use Future.wait, we can update UI as they finish)

      Future<void> processContentsRecursive(List<dynamic> items) async {
        for (var item in items) {
          final String type = item['type'];
          final String itemName = item['name'] ?? 'File';

          if ((type == 'video' || type == 'pdf' || type == 'image') &&
              item['isLocal'] == true) {
            final String? fPath = item['path'];
            if (fPath != null && fPath.isNotEmpty) {
              item['path'] = await copyToSafe(fPath, itemName);
            }
          }
          if (item['thumbnail'] != null && item['thumbnail'] is String) {
            final String tPath = item['thumbnail'];
            if (tPath.isNotEmpty && !tPath.startsWith('http')) {
              item['thumbnail'] = await copyToSafe(tPath, 'Thumbnail');
            }
          }
          if (type == 'folder' && item['contents'] != null) {
            await processContentsRecursive(item['contents']);
          }
        }
      }

      await processContentsRecursive(state.courseContents);

      if (state.thumbnailImage != null) {
        final newPath = await copyToSafe(
          state.thumbnailImage!.path,
          "Course Thumbnail",
        );
        state.thumbnailImage = File(newPath);
      }
      if (state.certificate1File != null) {
        final newPath = await copyToSafe(
          state.certificate1File!.path,
          "Certificate",
        );
        state.certificate1File = File(newPath);
      }

      final String docId = state.editingCourseId ??
          FirebaseFirestore.instance.collection('courses').doc().id;

      final draftCourse = CourseModel(
        id: docId,
        title: state.titleController.text.trim(),
        category: state.selectedCategory!,
        price: int.tryParse(state.mrpController.text) ?? 0,
        discountPrice: int.tryParse(state.finalPriceController.text) ?? 0,
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
        createdAt: state.originalCourse?.createdAt ?? DateTime.now(),
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

      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final List<Map<String, dynamic>> fileTasks = [];
      final Set<String> processedFilePaths = {};

      void addTask(
        String filePath,
        String remotePath,
        String id, {
        String? thumbnail,
      }) {
        if (processedFilePaths.contains(filePath)) return;
        processedFilePaths.add(filePath);
        fileTasks.add({
          'filePath': filePath,
          'remotePath': remotePath,
          'id': id,
          'thumbnail': thumbnail,
        });
      }

      if (state.thumbnailImage != null) {
        addTask(
          state.thumbnailImage!.path,
          'courses/$sessionId/thumbnails/thumb_${path.basename(state.thumbnailImage!.path)}',
          'thumb',
        );
      }

      if (state.hasCertificate) {
        if (state.certificate1File != null) {
          addTask(
            state.certificate1File!.path,
            'courses/$sessionId/certificates/cert1_${path.basename(state.certificate1File!.path)}',
            'cert1',
          );
        }
      }

      int globalCounter = 0;
      void processItemRecursive(dynamic item) {
        final int currentIndex = globalCounter++;
        final String type = item['type'];
        if ((type == 'video' || type == 'pdf' || type == 'image') &&
            item['isLocal'] == true) {
          final filePath = item['path'];
          if (filePath != null && filePath is String) {
            String folder = 'others';
            if (type == 'video') {
              folder = 'videos';
            } else if (type == 'pdf') {
              folder = 'pdfs';
            } else if (type == 'image') {
              folder = 'images';
            }

            final uniqueName = '${currentIndex}_${item['name']}';
            addTask(
              filePath,
              'courses/$sessionId/$folder/$uniqueName',
              filePath,
              thumbnail: (type == 'video' && item['thumbnail'] != null)
                  ? item['thumbnail']
                  : null,
            );
          }
        }
        if (item['thumbnail'] != null && item['thumbnail'] is String) {
          final String thumbPath = item['thumbnail'];
          if (thumbPath.isNotEmpty && !thumbPath.startsWith('http')) {
            addTask(
              thumbPath,
              'courses/$sessionId/thumbnails/thumb_${currentIndex}_${path.basename(thumbPath)}',
              thumbPath,
            );
          }
        }
        if (type == 'folder' && item['contents'] != null) {
          for (var sub in item['contents']) {
            processItemRecursive(sub);
          }
        }
      }

      for (var item in state.courseContents) {
        processItemRecursive(item);
      }

      final service = FlutterBackgroundService();

      // --- NEW: Reliable Command Delivery ---
      bool commandDelivered = false;
      int retryCount = 0;
      const int maxRetries = 15; // Wait up to 15 seconds for slow device bootup

      // 1. Start the service
      if (!await service.isRunning()) {
        await service.startService();
      }

      // 2. Persistent retry loop for "Double Tap" until status is confirmed
      // 3. Optimized Metadata Transfer (File-based instead of String-based)
      final String metadataFileName = 'course_metadata_${sessionId}.json';
      final File metadataFile = File('${safeDir.path}/$metadataFileName');

      final Map<String, dynamic> payload = {};
      
      // Function to fix types for JSON serialization
      void prepareMapForJson(Map<String, dynamic> map) {
        if (map['createdAt'] != null) {
           if (map['createdAt'] is Timestamp) {
              map['createdAt'] = (map['createdAt'] as Timestamp).toDate().toIso8601String();
           } else if (map['createdAt'] is DateTime) {
              map['createdAt'] = (map['createdAt'] as DateTime).toIso8601String();
           } else {
              // Convert FieldValue or others to current time string fallback
              map['createdAt'] = DateTime.now().toIso8601String();
           }
        }
      }

      if (state.editingCourseId != null) {
        final updateMap = draftCourse.toMap();
        prepareMapForJson(updateMap);
        
        payload['updateData'] = updateMap;
        payload['updateData'].remove('id'); // ID is passed separately
        payload['courseId'] = docId;
        payload['files'] = fileTasks;
      } else {
        final contentMap = draftCourse.toMap();
        prepareMapForJson(contentMap);
        
        payload['course'] = contentMap;
        payload['files'] = fileTasks;
      }

      await metadataFile.writeAsString(jsonEncode(payload));

      while (!commandDelivered && retryCount < maxRetries) {
        if (state.editingCourseId != null) {
          service.invoke('update_course', {'metadataPath': metadataFile.path});
        } else {
          service.invoke('submit_course', {'metadataPath': metadataFile.path});
        }
        service.invoke('get_status');

        await Future.delayed(const Duration(seconds: 1));

        final checkPrefs = await SharedPreferences.getInstance();
        final keyToCheck = state.editingCourseId != null
            ? 'pending_update_course_v1'
            : 'pending_course_v1';

        if (checkPrefs.containsKey(keyToCheck)) {
          commandDelivered = true;
          debugPrint("✅ SubmitHandler: Command delivered (via Metadata File)");
        }
        retryCount++;
      }

      await prefs.remove('course_creation_draft');

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

        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UploadProgressScreen()),
        );
      }
    } catch (e) {
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

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _jumpToStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    state.pageController.jumpToPage(step);
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
}
