import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'state_manager.dart';
import 'draft_manager.dart';

class Step2Logic {
  final CourseStateManager state;
  final DraftManager draftManager;

  Step2Logic(this.state, this.draftManager);

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
    state.isSelectionMode = true;
    state.selectedIndices.add(index);
    state.updateState();
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
    state.courseContents[index]['isLocked'] = !(state.courseContents[index]['isLocked'] ?? true);
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
    state.isDragModeActive = true;
    state.updateState();
  }

  void cancelHoldTimer() {
    _holdTimer?.cancel();
  }
}
