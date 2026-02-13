import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state_manager.dart';
import 'draft_manager.dart';

import 'history_manager.dart';

class Step3Logic {
  final CourseStateManager state;
  final DraftManager draftManager;
  final HistoryManager historyManager;

  Step3Logic(this.state, this.draftManager, this.historyManager);

  void updateSpecialTag(String text) {
    // Controller is already bound, just save draft
    // No haptic here because it's called on every keystroke
    draftManager.saveCourseDraft();
  }



  void setSpecialTagText(String text) {
    HapticFeedback.lightImpact();
    state.specialTagController.text = text;
    draftManager.saveCourseDraft();
  }


  void toggleSpecialTagVisibility(bool isVisible) {
    HapticFeedback.lightImpact();
    state.isSpecialTagVisible = isVisible;
    draftManager.saveCourseDraft();
  }


  void setSpecialTagDuration(int? days) {
    if (days != null) {
      HapticFeedback.lightImpact();
      state.specialTagDurationDays = days;
      draftManager.saveCourseDraft();
    }
  }


  void setSpecialTagColor(String colorName) {
    HapticFeedback.lightImpact();
    state.specialTagColor = colorName;
    state
        .updateState(); // Helper to notify listeners if needed immediately for UI feedback
    draftManager.saveCourseDraft();
  }


  void toggleOfflineDownload(bool isEnabled) {
    HapticFeedback.lightImpact();
    state.isOfflineDownloadEnabled = isEnabled;
    draftManager.saveCourseDraft();
  }


  void togglePublishStatus(bool isPublished) {
    HapticFeedback.lightImpact();
    state.isPublished = isPublished;
    draftManager.saveCourseDraft();
  }


  void clearAdvanceDraft(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Advanced Settings?'),
        content: const Text(
          'This will reset Special Tag, Offline Download, and Publish Status to defaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              state.specialTagController.clear();
              state.isSpecialTagVisible = false;
              state.specialTagDurationDays = 30;
              state.specialTagColor = 'Blue';
              state.isOfflineDownloadEnabled = false;
              state.isPublished = false;
              state.updateState();
              draftManager.saveCourseDraft();
              Navigator.pop(context);
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
