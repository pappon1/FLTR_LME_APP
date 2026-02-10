import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'state_manager.dart';
import 'draft_manager.dart';

import 'history_manager.dart';

class Step2Logic {
  final CourseStateManager state;
  final DraftManager draftManager;
  final HistoryManager historyManager;

  Step2Logic(this.state, this.draftManager, this.historyManager);

  void onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = state.courseContents.removeAt(oldIndex);
    state.courseContents.insert(newIndex, item);
    state.updateState();
    draftManager.saveCourseDraft();
  }

  void enterSelectionMode(int index) {
    HapticFeedback.heavyImpact();
    state.selectedIndices.add(index);
    state.isSelectionMode = true; // Triggers notifyListeners()
  }

  void toggleSelection(int index) {
    HapticFeedback.heavyImpact();
    if (state.selectedIndices.contains(index)) {
      state.selectedIndices.remove(index);
    } else {
      state.selectedIndices.add(index);
    }
    state.updateState();
  }

  void toggleLock(int index) {
    state.courseContents[index]['isLocked'] =
        !(state.courseContents[index]['isLocked'] ?? true);
    state.updateState();
    draftManager.saveCourseDraft();
  }

  // Timer logic for hold
  Timer? _holdTimer;
  void startHoldTimer(VoidCallback onTrigger) {
    if (state.isSelectionMode) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 600), onTrigger);
  }

  void enterDragMode() {
    HapticFeedback.heavyImpact();
    state.isDragModeActive = true; // Triggers notifyListeners()
  }

  void cancelHoldTimer() {
    _holdTimer?.cancel();
  }

  void clearContentDraft(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Course Content?'),
        content: const Text(
          'This will remove all videos, folders, and resources added. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              state.courseContents.clear();
              state.selectedIndices.clear();
              state.isSelectionMode = false;
              state.isDragModeActive = false;
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
