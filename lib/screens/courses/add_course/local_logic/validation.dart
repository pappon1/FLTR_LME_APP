import 'package:flutter/material.dart';
import 'state_manager.dart';

class ValidationLogic {
  final CourseStateManager state;

  ValidationLogic(this.state);

  bool validateAllFields({Function(String)? onValidationError}) {
    if (!validateStep0(onValidationError: onValidationError)) return false;
    if (!validateStep1_5(onValidationError: onValidationError)) return false;
    return true;
  }

  bool validateStep0({Function(String)? onValidationError}) {
    state.thumbnailError = false;
    state.titleError = false;
    state.descError = false;
    state.categoryError = false;
    state.difficultyError = false;
    state.batchDurationError = false;
    state.highlightsError = false;
    state.faqsError = false;

    bool isValid = true;
    String? firstError;
    String? errorType;
    double scrollOffset = 0;

    // 1. Check Thumbnail
    if (state.thumbnailImage == null) {
      state.thumbnailError = true;
      firstError ??= 'Please upload a cover image';
      errorType ??= 'thumbnail';
      scrollOffset = 0;
      isValid = false;
    }

    // 2. Check Title
    if (state.titleController.text.trim().isEmpty) {
      state.titleError = true;
      if (isValid) scrollOffset = 0;
      firstError ??= 'Please enter a course title';
      errorType ??= 'title';
      isValid = false;
    }

    // 3. Check Description
    if (state.descController.text.trim().isEmpty) {
      state.descError = true;
      if (isValid) scrollOffset = 0;
      firstError ??= 'Please enter a course description';
      errorType ??= 'desc';
      isValid = false;
    }

    // 4. Check Category
    if (state.selectedCategory == null) {
      state.categoryError = true;
      if (isValid) scrollOffset = 0;
      firstError ??= 'Please select a course category';
      errorType ??= 'category';
      isValid = false;
    }

    // 5. Check Difficulty
    if (state.difficulty == null) {
      state.difficultyError = true;
      if (isValid) scrollOffset = 0;
      firstError ??= 'Please select a course type';
      errorType ??= 'difficulty';
      isValid = false;
    }

    // 6. Check Duration
    if (state.newBatchDurationDays == null) {
      state.batchDurationError = true;
      if (isValid) scrollOffset = 0;
      firstError ??= 'Please select new badge duration';
      errorType ??= 'duration';
      isValid = false;
    }

    // 7. Check Highlights - Match OG: Fails if empty OR has any empty controller
    bool hasEmptyHighlight = state.highlightControllers.any((c) => c.text.trim().isEmpty);
    if (state.highlightControllers.isEmpty || hasEmptyHighlight) {
      state.highlightsError = true;
      if (isValid) scrollOffset = 600;
      firstError ??= 'Please add at least one highlight';
      errorType ??= 'highlights';
      isValid = false;
    }

    // 8. Check FAQs - Match OG: Fails if empty OR has any empty controller
    bool hasEmptyFaq = state.faqControllers.any((f) =>
        (f['q']?.text.trim().isEmpty ?? true) ||
        (f['a']?.text.trim().isEmpty ?? true)
    );
    if (state.faqControllers.isEmpty || hasEmptyFaq) {
      state.faqsError = true;
      if (isValid) scrollOffset = 800;
      firstError ??= 'Please add at least one FAQ';
      errorType ??= 'faqs';
      isValid = false;
    }

    if (!isValid) {
      state.updateState();
      
      // Handle focuses and scrolls
      if (errorType == 'title') {
        state.titleFocus.requestFocus();
      } else if (errorType == 'desc') {
        state.descFocus.requestFocus();
      } else if (state.scrollController.hasClients) {
        state.scrollController.animateTo(
          scrollOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      if (onValidationError != null && firstError != null) {
        onValidationError(firstError);
      }
    }

    return isValid;
  }

  bool validateStep1_5({Function(String)? onValidationError}) {
    state.mrpError = false;
    state.discountError = false;
    state.languageError = false;
    state.courseModeError = false;
    state.supportTypeError = false;
    state.wpGroupLinkError = false;
    state.validityError = false;
    state.certError = false;
    state.bigScreenUrlError = false;

    bool isValid = true;
    String? firstError;

    if (state.mrpController.text.trim().isEmpty) {
      state.mrpError = true;
      firstError ??= 'Please enter MRP (Price)';
      isValid = false;
    }

    if (state.discountAmountController.text.trim().isEmpty) {
      state.discountError = true;
      firstError ??= 'Please enter Discount Amount';
      isValid = false;
    }

    if (state.selectedLanguage == null) {
      state.languageError = true;
      firstError ??= 'Please select Course Language';
      isValid = false;
    }

    if (state.selectedCourseMode == null) {
      state.courseModeError = true;
      firstError ??= 'Please select Course Mode';
      isValid = false;
    }

    if (state.selectedSupportType == null) {
      state.supportTypeError = true;
      firstError ??= 'Please select Support Type';
      isValid = false;
    }

    if (state.selectedSupportType == 'WhatsApp Group' && state.whatsappController.text.trim().isEmpty) {
      state.wpGroupLinkError = true;
      firstError ??= 'Please paste WhatsApp Group Link';
      isValid = false;
    }

    if (state.courseValidityDays == null) {
      state.validityError = true;
      firstError ??= 'Please select Course Validity';
      isValid = false;
    }

    if (state.hasCertificate && state.certificate1Image == null && state.certificate2Image == null) {
      state.certError = true;
      firstError ??= 'Please upload at least one certificate design';
      isValid = false;
    }

    if (state.isBigScreenEnabled && state.websiteUrlController.text.trim().isEmpty) {
      state.bigScreenUrlError = true;
      firstError ??= 'Please enter Website Login URL';
      isValid = false;
    }

    if (!isValid) {
      state.updateState();
      if (state.scrollController.hasClients) {
        state.scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
      if (onValidationError != null && firstError != null) {
        onValidationError(firstError);
      }
    }

    return isValid;
  }
}
