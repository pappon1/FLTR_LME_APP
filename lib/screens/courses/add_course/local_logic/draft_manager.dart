import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/logger_service.dart';
import 'state_manager.dart';

class DraftManager {
  final CourseStateManager state;
  Timer? _saveDebounce;

  DraftManager(this.state);

  Future<void> loadCourseDraft() async {
    try {
      state.isRestoringDraft = true;
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('course_creation_draft');
      if (jsonString != null) {
        final Map<String, dynamic> draft = jsonDecode(jsonString);

        state.titleController.text = draft['title'] ?? '';
        state.descController.text = draft['desc'] ?? '';
        state.mrpController.text = draft['mrp'] ?? '';
        state.discountAmountController.text = draft['discount'] ?? '';
        state.selectedCategory = draft['category'];
        state.difficulty = draft['difficulty'];
        state.selectedLanguage = draft['language'];
        state.selectedCourseMode = draft['courseMode'];
        state.selectedSupportType = draft['supportType'];
        state.whatsappController.text = draft['whatsappNumber'] ?? '';
        state.specialTagController.text = draft['specialTag'] ?? '';
        state.isBigScreenEnabled = draft['isBigScreenEnabled'] ?? false;
        state.websiteUrlController.text = draft['websiteUrl'] ?? '';

        if (draft['contents'] != null) {
          state.courseContents.clear();
          state.courseContents.addAll(
            List<Map<String, dynamic>>.from(draft['contents']),
          );
        }

        state.courseValidityDays = draft['validity'];
        state.hasCertificate = draft['certificate'] ?? false;
        state.isOfflineDownloadEnabled = draft['offlineDownload'] ?? true;
        state.isPublished = draft['isPublished'] ?? false;
        state.newBatchDurationDays = draft['newBatchDuration'];

        if (draft['customDays'] != null) {
          state.customValidityController.text = draft['customDays'].toString();
        }

        // Restore Image Paths
        bool missingFiles = false;
        if (draft['thumbnailPath'] != null) {
          final file = File(draft['thumbnailPath']);
          if (file.existsSync()) {
            state.thumbnailImage = file;
          } else {
            missingFiles = true;
          }
        }
        if (draft['cert1Path'] != null) {
          final file = File(draft['cert1Path']);
          if (file.existsSync()) {
            state.certificate1File = file;
          } else {
            missingFiles = true;
          }
        }

        if (missingFiles) {
          LoggerService.warning('Some draft files were missing and could not be restored.', tag: 'DRAFT');
        }

        // Restore Highlights
        if (draft['highlights'] != null) {
          state.highlightControllers.clear();
          for (var h in draft['highlights']) {
            state.highlightControllers.add(TextEditingController(text: h));
          }
        }

        // Restore FAQs
        if (draft['faqs'] != null) {
          state.faqControllers.clear();
          for (var f in draft['faqs']) {
            state.faqControllers.add({
              'q': TextEditingController(text: f['question']),
              'a': TextEditingController(text: f['answer']),
            });
          }
        }
        state.updateState();
      }
    } catch (e) {
      LoggerService.error('Draft Load Error: $e', tag: 'DRAFT');
    } finally {
      state.isRestoringDraft = false;
    }
  }

  Future<void> saveCourseDraft({bool immediate = false}) async {
    if (state.isRestoringDraft) return;
    if (_saveDebounce?.isActive ?? false) _saveDebounce!.cancel();

    if (immediate) {
      await executeDraftSave();
      return;
    }

    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      await executeDraftSave();
    });
  }

  Future<void> executeDraftSave() async {
    try {
      state.isSavingDraft = true;
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> draft = {
        'title': state.titleController.text,
        'desc': state.descController.text,
        'mrp': state.mrpController.text,
        'discount': state.discountAmountController.text,
        'category': state.selectedCategory,
        'difficulty': state.difficulty,
        'contents': state.courseContents,
        'validity': state.courseValidityDays,
        'certificate': state.hasCertificate,
        'offlineDownload': state.isOfflineDownloadEnabled,
        'isPublished': state.isPublished,
        'language': state.selectedLanguage,
        'courseMode': state.selectedCourseMode,
        'supportType': state.selectedSupportType,
        'whatsappNumber': state.whatsappController.text.trim(),
        'specialTag': state.specialTagController.text.trim(),
        'isBigScreenEnabled': state.isBigScreenEnabled,
        'websiteUrl': state.websiteUrlController.text.trim(),
        'customDays': int.tryParse(state.customValidityController.text),
        'thumbnailPath': state.thumbnailImage?.path,
        'newBatchDuration': state.newBatchDurationDays,
        'cert1Path': state.certificate1File?.path,
        'highlights': state.highlightControllers.map((c) => c.text).toList(),
        'faqs': state.faqControllers
            .map((f) => {'question': f['q']!.text, 'answer': f['a']!.text})
            .toList(),
      };

      await prefs.setString('course_creation_draft', jsonEncode(draft));
      state.isSavingDraft = false;
      LoggerService.info('Course draft saved successfully', tag: 'DRAFT');
    } catch (e) {
      state.isSavingDraft = false;
      LoggerService.error('Draft Save Error: $e', tag: 'DRAFT');
    }
  }

  void dispose() {
    _saveDebounce?.cancel();
  }
}
