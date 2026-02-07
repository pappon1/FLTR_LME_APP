import 'package:flutter/material.dart';
import 'state_manager.dart';
import 'validation.dart';
import 'draft_manager.dart';

class NavigationLogic {
  final CourseStateManager state;
  final PageController pageController;
  final ValidationLogic validation;
  final DraftManager draftManager;
  final BuildContext context;

  NavigationLogic(
    this.state,
    this.pageController,
    this.validation,
    this.draftManager,
    this.context,
  );

  void nextStep(Function(String) showWarning) {
    if (state.currentStep == 0) {
      if (validation.validateStep0(onValidationError: showWarning)) {
        _animateToPage(1);
      }
    } else if (state.currentStep == 1) {
      if (validation.validateStep1_5(onValidationError: showWarning)) {
        _animateToPage(2);
      }
    } else if (state.currentStep == 2) {
      if (state.courseContents.isEmpty) {
        state.courseContentError = true;
        state.updateState();
        showWarning('Please add at least one content to proceed');
        return;
      } else {
        state.courseContentError = false;
        state.updateState();
        _animateToPage(3);
      }
    }
  }

  void prevStep() {
    if (state.currentStep > 0) {
      _animateToPage(state.currentStep - 1);
    }
  }

  void jumpToStep(int step) {
    _animateToPage(step);
  }

  Future<void> _animateToPage(int page) async {
    // Unfocus immediately
    FocusScope.of(context).unfocus();

    // Jump instantly without animation
    pageController.jumpToPage(page);
    state.currentStep = page;
  }
}
