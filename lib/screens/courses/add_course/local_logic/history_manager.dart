import 'package:flutter/material.dart';
import 'state_manager.dart';
import '../../../../services/logger_service.dart';
import 'draft_manager.dart';

class HistoryManager {
  final CourseStateManager state;
  final DraftManager draftManager;

  // Stacks for Undo/Redo
  final List<Map<String, dynamic>> _undoStack = [];
  final List<Map<String, dynamic>> _redoStack = [];

  // Max stack size to prevent memory issues
  static const int _maxStackSize = 50;

  bool _isPerformingUndoRedo = false;

  HistoryManager(this.state, this.draftManager);

  /// Captures the current state and pushes it to the Undo stack.
  /// Call this BEFORE applying a change, or right after a significant change is committed (debounced).
  /// Given the current DraftManager architecture where we save *after* changes,
  /// a good strategy is to capture snapshot *before* a change starts?
  /// Or simpler: Every time [DraftManager.executeDraftSave] runs, we can also push to history?
  /// BUT, standard Undo/Redo works best if we capture the state *before* it changes.
  /// However, since we don't have a centralized "dispatch" for every field edit,
  /// we can rely on debounced snapshots.
  ///
  /// Strategy: Every time a snapshot is captured (e.g. by DraftManager or manual trigger),
  /// we add it to the stack.
  ///
  /// Actually, meaningful specific actions (add section, delete section) should trigger a snapshot.
  /// Text typing is harder.
  ///
  /// Let's expose a method [captureState] used by Logic classes.
  void captureState() {
    if (_isPerformingUndoRedo) return;

    final snapshot = draftManager.createSnapshot();
    
    // Avoid duplicate adjacent snapshots
    if (_undoStack.isNotEmpty) {
      // Basic check: compare lastUpdated or a quick hash? content comparison is expensive.
      // For now, just push.
    }

    _undoStack.add(snapshot);
    if (_undoStack.length > _maxStackSize) {
      _undoStack.removeAt(0);
    }
    
    // Clear redo stack on new change
    _redoStack.clear();
    
    // Notify UI (Undo button enablement changes)
    // We use a microtask or just call it, but verify we are not in build.
    // Since this is called from Debounce (Timer), it's safe.
    state.updateState();
    
    LoggerService.info('State Captured. Undo Stack: ${_undoStack.length}', tag: 'HISTORY');
  }

  bool get canUndo => _undoStack.length > 1; // Need at least 1 previous state to undo TO
  bool get canRedo => _redoStack.isNotEmpty;

  void undo(BuildContext context) {
    if (_undoStack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to undo')),
      );
      return;
    }

    _isPerformingUndoRedo = true;
    try {
      // 1. Save current state to Redo Stack
      final currentSnapshot = draftManager.createSnapshot();
      _redoStack.add(currentSnapshot);

      // 2. Pop the latest state from Undo Stack (which represents "Current" before this undo)
      // Actually, if we capture state continuously, the top of Undo Stack is "Current".
      // So we pop it (discard or move to redo), and peek the *previous* one.
      
      // If we only captured *before* changes, top of stack is "Previous".
      // But if we capture *after* changes (via DraftManager debouncer), top is "Current".
      // Let's assume top is "Current".
      
      if (_undoStack.length < 2) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Initial state reached')),
        );
        _isPerformingUndoRedo = false;
        return;
      }

      _undoStack.removeLast(); // Remove "Current"
      final previousSnapshot = _undoStack.last; // Get "Previous"

      // 3. Restore
      draftManager.restoreFromSnapshot(previousSnapshot);
      state.updateState(); // Notify listeners
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Undone'), duration: Duration(milliseconds: 500)),
      );
      
    } catch (e) {
      LoggerService.error('Undo Failed: $e', tag: 'HISTORY');
    } finally {
      _isPerformingUndoRedo = false;
    }
  }

  void redo(BuildContext context) {
    if (_redoStack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to redo')),
      );
      return;
    }

    _isPerformingUndoRedo = true;
    try {
      // 1. Pop from Redo
      final nextSnapshot = _redoStack.removeLast();

      // 2. Save current (which is "Previous" relative to next) to Undo
      // Actually, just push the restored snapshot to Undo
      _undoStack.add(nextSnapshot);

      // 3. Restore
      draftManager.restoreFromSnapshot(nextSnapshot);
      state.updateState();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Redone'), duration: Duration(milliseconds: 500)),
      );

    } catch (e) {
      LoggerService.error('Redo Failed: $e', tag: 'HISTORY');
    } finally {
      _isPerformingUndoRedo = false;
    }
  }
}
