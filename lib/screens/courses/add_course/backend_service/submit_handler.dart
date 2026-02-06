import 'dart:async';
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
import '../../../../screens/uploads/upload_progress_screen.dart';

class SubmitHandler {
  final CourseStateManager state;
  final ValidationLogic validation;

  SubmitHandler(this.state, this.validation);

  Future<void> submitCourse(BuildContext context, Function(String) showWarning) async {
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

      Future<String> copyToSafe(String rawPath) async {
        if (copiedPathMap.containsKey(rawPath)) return copiedPathMap[rawPath]!;
        final f = File(rawPath);
        if (!f.existsSync()) return rawPath;
        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(rawPath)}';
        final newPath = '${safeDir.path}/$filename';
        await f.copy(newPath);
        copiedPathMap[rawPath] = newPath;
        return newPath;
      }

      if (state.thumbnailImage != null) {
        state.thumbnailImage = File(await copyToSafe(state.thumbnailImage!.path));
      }
      if (state.certificate1File != null) {
        state.certificate1File = File(await copyToSafe(state.certificate1File!.path));
      }

      Future<void> safeCopyAllContent(List<dynamic> items) async {
        for (var item in items) {
          final String type = item['type'];
          if ((type == 'video' || type == 'pdf' || type == 'image') &&
              item['isLocal'] == true) {
            final String? fPath = item['path'];
            if (fPath != null && fPath.isNotEmpty) {
              item['path'] = await copyToSafe(fPath);
            }
          }
          if (item['thumbnail'] != null && item['thumbnail'] is String) {
            final String tPath = item['thumbnail'];
            if (tPath.isNotEmpty && !tPath.startsWith('http')) {
              item['thumbnail'] = await copyToSafe(tPath);
            }
          }
          if (type == 'folder' && item['contents'] != null) {
            await safeCopyAllContent(item['contents']);
          }
        }
      }

      await safeCopyAllContent(state.courseContents);

      final newDocId = FirebaseFirestore.instance.collection('courses').doc().id;

      final draftCourse = CourseModel(
        id: newDocId,
        title: state.titleController.text.trim(),
        category: state.selectedCategory!,
        price: int.tryParse(state.mrpController.text) ?? 0,
        discountPrice: int.tryParse(state.finalPriceController.text) ?? 0,
        description: finalDesc,
        thumbnailUrl: state.thumbnailImage?.path ?? '',
        duration: finalValidity == 0 ? 'Lifetime Access' : '$finalValidity Days',
        difficulty: state.difficulty!,
        enrolledStudents: 0,
        rating: 0.0,
        totalVideos: _countVideos(state.courseContents),
        isPublished: state.isPublished,
        createdAt: DateTime.now(),
        newBatchDays: state.newBatchDurationDays!,
        courseValidityDays: finalValidity,
        hasCertificate: state.hasCertificate,
        certificateUrl1: state.certificate1File?.path,
        selectedCertificateSlot: 1,
        isOfflineDownloadEnabled: state.isOfflineDownloadEnabled,
        language: state.selectedLanguage!,
        courseMode: state.selectedCourseMode!,
        supportType: state.selectedSupportType!,
        whatsappNumber: state.whatsappController.text.trim(),
        isBigScreenEnabled: state.isBigScreenEnabled,
        websiteUrl: state.websiteUrlController.text.trim(),
        specialTag: state.specialTagController.text.trim(),
        contents: state.courseContents,
        highlights: state.highlightControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        faqs: state.faqControllers
            .map((f) => {
                  'question': f['q']!.text.trim(),
                  'answer': f['a']!.text.trim(),
                })
            .where((f) => f['question']!.isNotEmpty && f['answer']!.isNotEmpty)
            .toList(),
      );

      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final List<Map<String, dynamic>> fileTasks = [];
      final Set<String> processedFilePaths = {};

      void addTask(String filePath, String remotePath, String id, {String? thumbnail}) {
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
              thumbnail: (type == 'video' && item['thumbnail'] != null) ? item['thumbnail'] : null,
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

      final courseMap = draftCourse.toMap();
      courseMap['createdAt'] = DateTime.now().toIso8601String();

      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
        await Future.delayed(const Duration(seconds: 4));
      }

      service.invoke('submit_course', {
        'course': courseMap,
        'files': fileTasks,
      });

      Timer(const Duration(milliseconds: 1500), () {
        service.invoke('submit_course', {
          'course': courseMap,
          'files': fileTasks,
        });
        service.invoke('get_status');
      });

      service.invoke('get_status');

      await prefs.remove('course_creation_draft');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload Started in Background 🚀'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
  }
}
