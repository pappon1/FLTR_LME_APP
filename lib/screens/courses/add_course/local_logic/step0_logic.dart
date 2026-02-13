import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'state_manager.dart';
import 'draft_manager.dart';
import 'history_manager.dart';

class Step0Logic {
  final CourseStateManager state;
  final DraftManager draftManager;
  final HistoryManager historyManager;

  Step0Logic(this.state, this.draftManager, this.historyManager);

  Future<void> pickImage(
    BuildContext context,
    Function(String) showWarning,
  ) async {
    try {
      final picker = ImagePicker();
      state.isLoading = true;
      state.updateState();

      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (pickedFile != null) {
        final File file = File(pickedFile.path);
        final decodedImage = await decodeImageFromList(
          await file.readAsBytes(),
        );

        final double ratio = decodedImage.width / decodedImage.height;
        if (ratio < 1.7 || ratio > 1.85) {
          if (context.mounted) {
            showWarning('Error: Image must be YouTube Size (16:9 Ratio).');
          }
          state.isLoading = false;
          state.updateState();
          return;
        }

        // Success Haptic
        HapticFeedback.mediumImpact();

        state.thumbnailImage = file;
        state.thumbnailError = false;
        state.isLoading = false;
        state.updateState();
        await draftManager.saveCourseDraft();
      } else {
        state.isLoading = false;
        state.updateState();
      }
    } catch (e) {
      state.isLoading = false;
      state.updateState();
      if (context.mounted) {
        showWarning('Error picking image: $e');
      }
    }
  }

  void _performClearBasicInfo() {
    state.titleController.clear();
    state.descController.clear();
    state.selectedCategory = null;
    state.difficulty = null;
    state.thumbnailImage = null;

    // Dispose and clear controllers
    for (var c in state.highlightControllers) {
      c.dispose();
    }
    state.highlightControllers.clear();

    for (var f in state.faqControllers) {
      f['q']?.dispose();
      f['a']?.dispose();
    }
    state.faqControllers.clear();

    // Reset error flags
    state.thumbnailError = false;
    state.titleError = false;
    state.descError = false;
    state.categoryError = false;
    state.difficultyError = false;

    state.highlightsError = false;
    state.faqsError = false;

    state.updateState();
    draftManager.saveCourseDraft();
  }

  void addHighlight() {
    state.highlightsError = false;
    state.highlightControllers.add(TextEditingController());
    state.updateState();
  }

  void removeHighlight(int index) {
    state.highlightControllers[index].dispose();
    state.highlightControllers.removeAt(index);
    state.updateState();
    draftManager.saveCourseDraft();
  }

  void addFAQ() {
    state.faqsError = false;
    state.faqControllers.add({
      'q': TextEditingController(),
      'a': TextEditingController(),
    });
    state.updateState();
  }

  void removeFAQ(int index) {
    state.faqControllers[index]['q']?.dispose();
    state.faqControllers[index]['a']?.dispose();
    state.faqControllers.removeAt(index);
    state.updateState();
    draftManager.saveCourseDraft();
  }

  void clearBasicDraft(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Basic Info?'),
        content: const Text(
          'This will reset everything on this screen (Step 1). Content and Settings in Step 2 & 3 will remain safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _performClearBasicInfo();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _performClearAll() {
    state.resetAll();
    draftManager.saveCourseDraft();
  }

  void clearAllDrafts(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear EVERYTHING?'),
        content: const Text(
          'WARNING: This will wipe ALL data from ALL steps (Basic Info, Setup, Content, Advanced). This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _performClearAll();
              Navigator.pop(context);
            },
            child: const Text(
              'CLEAR ALL',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
