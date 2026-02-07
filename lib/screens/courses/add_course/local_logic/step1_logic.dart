import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'state_manager.dart';
import 'draft_manager.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class Step1Logic {
  final CourseStateManager state;
  final DraftManager draftManager;

  Step1Logic(this.state, this.draftManager);

  Future<void> checkUrlValidity(String url, {required bool isWhatsapp}) async {
    if (url.isEmpty) {
      if (isWhatsapp) {
        state.isWpChecking = false;
        state.isWpValid = false;
        state.wpGroupLinkError = false;
      } else {
        state.isWebChecking = false;
        state.isWebValid = false;
        state.bigScreenUrlError = false;
      }
      state.updateState();
      return;
    }

    if (isWhatsapp) {
      state.isWpChecking = true;
      state.wpGroupLinkError = false;
    } else {
      state.isWebChecking = true;
      state.bigScreenUrlError = false;
    }
    state.updateState();

    try {
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }

      final uri = Uri.tryParse(url);
      if (uri == null) throw Exception('Invalid URL Format');

      if (isWhatsapp) {
        if (!uri.host.contains('chat.whatsapp.com')) {
          throw Exception('Invalid Domain');
        }
      }

      final response = await http.head(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 400) {
        if (isWhatsapp) {
          state.isWpValid = true;
        } else {
          state.isWebValid = true;
        }
      } else {
        throw Exception('Unreachable');
      }
    } catch (e) {
      if (isWhatsapp) {
        state.isWpValid = false;
        state.wpGroupLinkError = true;
      } else {
        state.isWebValid = false;
        state.bigScreenUrlError = true;
      }
    } finally {
      if (isWhatsapp) {
        state.isWpChecking = false;
      } else {
        state.isWebChecking = false;
      }
      state.updateState();
      await draftManager.saveCourseDraft();
    }
  }

  void _performClearSetupInfo() {
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
    state.certificate1File = null;
    state.isBigScreenEnabled = false;
    state.websiteUrlController.clear();

    // Reset status flags
    state.isWpValid = false;
    state.isWebValid = false;
    state.wpGroupLinkError = false;
    state.bigScreenUrlError = false;
    state.languageError = false;
    state.courseModeError = false;
    state.supportTypeError = false;
    state.validityError = false;
    state.certError = false;
    state.mrpError = false;
    state.discountError = false;

    state.updateState();
    draftManager.saveCourseDraft();
  }

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
              _performClearSetupInfo();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> pickCertificatePdf(
    BuildContext context,
    Function(String) showWarning,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final File file = File(result.files.single.path!);

        final int sizeInBytes = file.lengthSync();
        final double sizeInMb = sizeInBytes / (1024 * 1024);
        if (sizeInMb > 10) {
          if (context.mounted) {
            showWarning('PDF size should be less than 10MB');
          }
          return;
        }

        state.certificate1File = file;
        state.certError = false;
        state.updateState();
        await draftManager.saveCourseDraft();
      }
    } catch (e) {
      if (context.mounted) {
        showWarning('Error picking PDF: $e');
      }
    }
  }
}
