import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'state_manager.dart';
import 'draft_manager.dart';

class Step0Logic {
  final CourseStateManager state;
  final DraftManager draftManager;

  Step0Logic(this.state, this.draftManager);

  Future<void> pickImage(BuildContext context, Function(String) showWarning) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final File file = File(pickedFile.path);
      final decodedImage = await decodeImageFromList(file.readAsBytesSync());

      final double ratio = decodedImage.width / decodedImage.height;
      if (ratio < 1.7 || ratio > 1.85) {
        showWarning('Error: Image must be YouTube Size (16:9 Ratio).');
        return;
      }

      state.thumbnailImage = file;
      state.thumbnailError = false;
      state.updateState();
      await draftManager.saveCourseDraft();
    }
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
              state.titleController.clear();
              state.descController.clear();
              state.selectedCategory = null;
              state.difficulty = null;
              state.thumbnailImage = null;
              state.newBatchDurationDays = null;
              for (var c in state.highlightControllers) {
                c.dispose();
              }
              state.highlightControllers.clear();
              for (var f in state.faqControllers) {
                f['q']?.dispose();
                f['a']?.dispose();
              }
              state.faqControllers.clear();
              state.thumbnailError = false;
              state.titleError = false;
              state.descError = false;
              state.categoryError = false;
              state.difficultyError = false;
              state.batchDurationError = false;
              state.highlightsError = false;
              state.faqsError = false;
              state.updateState();
              draftManager.saveCourseDraft();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
