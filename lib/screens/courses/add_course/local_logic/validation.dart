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
    GlobalKey? firstErrorKey;
    String? errorType; // for focusing

    // 1. Check Thumbnail
    if (state.thumbnailImage == null) {
      state.thumbnailError = true;
      if (isValid) {
        firstError = 'Please upload a cover image';
        firstErrorKey = state.thumbnailKey;
        errorType = 'thumbnail';
      }
      isValid = false;
    }

    // 2. Check Title
    if (state.titleController.text.trim().isEmpty) {
      state.titleError = true;
      if (isValid) {
        firstError = 'Please enter a course title';
        firstErrorKey = state.titleKey;
        errorType = 'title';
      }
      isValid = false;
    }

    // 3. Check Description
    if (state.descController.text.trim().isEmpty) {
      state.descError = true;
      if (isValid) {
        firstError = 'Please enter a course description';
        firstErrorKey = state.descKey;
        errorType = 'desc';
      }
      isValid = false;
    }

    // 4. Check Category
    if (state.selectedCategory == null) {
      state.categoryError = true;
      if (isValid) {
        firstError = 'Please select a course category';
        firstErrorKey = state.categoryKey;
        errorType = 'category';
      }
      isValid = false;
    }

    // 5. Check Difficulty
    if (state.difficulty == null) {
      state.difficultyError = true;
      if (isValid) {
        firstError = 'Please select a course type';
        firstErrorKey = state.categoryKey; // In the same row as category
        errorType = 'difficulty';
      }
      isValid = false;
    }

    // 6. Check Duration
    if (state.newBatchDurationDays == null) {
      state.batchDurationError = true;
      if (isValid) {
        firstError = 'Please select new badge duration';
        firstErrorKey = state.difficultyKey; // Mapped to Duration in UI
        errorType = 'duration';
      }
      isValid = false;
    }

    // 7. Check Highlights
    bool hasEmptyHighlight = state.highlightControllers.any((c) => c.text.trim().isEmpty);
    if (state.highlightControllers.isEmpty || hasEmptyHighlight) {
      state.highlightsError = true;
      if (isValid) {
        firstError = 'Please add at least one highlight';
        firstErrorKey = state.highlightsKey;
        errorType = 'highlights';
      }
      isValid = false;
    }

    // 8. Check FAQs
    bool hasEmptyFaq = state.faqControllers.any((f) =>
        (f['q']?.text.trim().isEmpty ?? true) ||
        (f['a']?.text.trim().isEmpty ?? true)
    );
    if (state.faqControllers.isEmpty || hasEmptyFaq) {
      state.faqsError = true;
      if (isValid) {
        firstError = 'Please add at least one FAQ';
        firstErrorKey = state.faqsKey;
        errorType = 'faqs';
      }
      isValid = false;
    }

    if (!isValid) {
      state.updateState();
      
      // Handle focuses
      if (errorType == 'title') {
        state.titleFocus.requestFocus();
      } else if (errorType == 'desc') {
        state.descFocus.requestFocus();
      }

      // Handle Scrolling
      if (firstErrorKey != null && firstErrorKey!.currentContext != null) {
        Scrollable.ensureVisible(
          firstErrorKey!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1, // Scroll slightly below top
        );
      } else if (state.scrollController.hasClients) {
        // Fallback
        state.scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      if (onValidationError != null && firstError != null) {
        onValidationError(firstError!);
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
    GlobalKey? firstErrorKey;

    if (state.mrpController.text.trim().isEmpty) {
      state.mrpError = true;
      if (isValid) {
        firstError = 'Please enter MRP (Price)';
        firstErrorKey = state.mrpKey;
      }
      isValid = false;
    }

    if (state.discountAmountController.text.trim().isEmpty) {
      state.discountError = true;
      if (isValid) {
        firstError = 'Please enter Discount Amount';
        firstErrorKey = state.discountKey;
      }
      isValid = false;
    }

    if (state.selectedLanguage == null) {
      state.languageError = true;
      if (isValid) {
        firstError = 'Please select Course Language';
        firstErrorKey = state.languageKey;
      }
      isValid = false;
    }

    if (state.selectedCourseMode == null) {
      state.courseModeError = true;
      if (isValid) {
        firstError = 'Please select Course Mode';
        firstErrorKey = state.courseModeKey;
      }
      isValid = false;
    }

    if (state.selectedSupportType == null) {
      state.supportTypeError = true;
      if (isValid) {
        firstError = 'Please select Support Type';
        firstErrorKey = state.supportTypeKey;
      }
      isValid = false;
    }

    if (state.selectedSupportType == 'WhatsApp Group' && state.whatsappController.text.trim().isEmpty) {
      state.wpGroupLinkError = true;
      if (isValid) {
         firstError = 'Please paste WhatsApp Group Link';
         firstErrorKey = state.whatsappKey;
      }
      isValid = false;
    }

    if (state.courseValidityDays == null) {
      state.validityError = true;
      if (isValid) {
        firstError = 'Please select Course Validity';
        firstErrorKey = state.validityKey;
      }
      isValid = false;
    }

    if (state.hasCertificate && state.certificate1File == null) {
      state.certError = true;
      if (isValid) {
        firstError = 'Please upload certificate design PDF';
        firstErrorKey = state.certificateKey;
      }
      isValid = false;
    }

    if (state.isBigScreenEnabled && state.websiteUrlController.text.trim().isEmpty) {
      state.bigScreenUrlError = true;
      if (isValid) {
        firstError = 'Please enter Website Login URL';
        firstErrorKey = state.bigScreenKey;
      }
      isValid = false;
    }

    if (!isValid) {
      state.updateState();
      
      if (firstErrorKey != null && firstErrorKey!.currentContext != null) {
        Scrollable.ensureVisible(
          firstErrorKey!.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      } else if (state.scrollController.hasClients) {
        state.scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
      
      if (onValidationError != null && firstError != null) {
        onValidationError(firstError!);
      }
    }

    return isValid;
  }
}
