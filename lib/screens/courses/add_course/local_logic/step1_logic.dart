import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'state_manager.dart';
import 'draft_manager.dart';

class Step1Logic {
  final CourseStateManager state;
  final DraftManager draftManager;

  Step1Logic(this.state, this.draftManager);

  void clearSetupDraft(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Setup Info?'),
        content: const Text(
          'This will reset Pricing, Validity, Language and Certificate settings. Basic Info and Content will remain safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              state.mrpController.clear();
              state.discountAmountController.clear();
              state.finalPriceController.clear();
              state.selectedLanguage = null;
              state.selectedCourseMode = null;
              state.selectedSupportType = null;
              state.whatsappController.clear();
              state.courseValidityDays = null;
              state.customValidityController.clear();
              state.hasCertificate = false;
              state.certificate1Image = null;
              state.certificate2Image = null;
              state.selectedCertSlot = 1;
              state.isBigScreenEnabled = false;
              state.websiteUrlController.clear();
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

  Future<void> pickCertificateImage(BuildContext context, int slot, Function(String) showWarning) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final File file = File(pickedFile.path);

      // Validation for Custom Certificate Size
      final decodedImage = await decodeImageFromList(file.readAsBytesSync());
      if (decodedImage.width != 3508 || decodedImage.height != 2480) {
        showWarning('Error: Image must be 3508x2480 px. Current: ${decodedImage.width}x${decodedImage.height}');
        return;
      }

      if (slot == 1) {
        state.certificate1Image = file;
        state.selectedCertSlot = 1; // Auto select if uploaded
      } else {
        state.certificate2Image = file;
        state.selectedCertSlot = 2; // Auto select if uploaded
      }
      state.updateState();
      await draftManager.saveCourseDraft();
    }
  }
}
