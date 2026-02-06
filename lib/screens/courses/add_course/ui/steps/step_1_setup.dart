import 'package:flutter/material.dart';
import '../../../../../utils/app_theme.dart';
import '../ui_constants.dart';
import '../../local_logic/state_manager.dart';
import '../../local_logic/step1_logic.dart';
import '../components/collapsing_step_indicator.dart';
import '../components/text_field.dart';
import '../components/pdf_uploader.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class Step1SetupWidget extends StatelessWidget {
  final CourseStateManager state;
  final Step1Logic logic;
  final Widget navButtons;
  final Function(String) showWarning;

  const Step1SetupWidget({
    super.key,
    required this.state,
    required this.logic,
    required this.navButtons,
    required this.showWarning,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return CustomScrollView(
          controller: state.scrollController,
          slivers: [
            SliverPersistentHeader(
              delegate: CollapsingStepIndicator(
                currentStep: 1,
                isSelectionMode: false,
                isDragMode: false,
                brightness: Theme.of(context).brightness,
              ),
              pinned: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: UIConstants.screenPadding),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: UIConstants.s2HeaderSpace),
                    
                    _buildPricingSection(context),
                    const SizedBox(height: UIConstants.s2LanguageSpace),
    
                    _buildLanguageSupportSection(context),
                    const SizedBox(height: UIConstants.s2ValiditySpace),
    
                    _buildValiditySection(context),
                    const SizedBox(height: 24),
    
                    _buildCertificateSection(context),
                    const SizedBox(height: UIConstants.certToBigScreenSpace),
    
                    _buildBigScreenToggle(context),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: navButtons,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Course Setup',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: UIConstants.labelFontSize + 2,
              ),
            ),
            TextButton.icon(
              onPressed: () => logic.clearSetupDraft(context),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Clear Draft', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
              ),
            ),
          ],
        ),
        ValueListenableBuilder<bool>(
          valueListenable: state.isSavingDraftNotifier,
          builder: (context, isSaving, _) {
            return Visibility(
              visible: state.hasSetupContent,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3.0),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isSaving
                        ? const SizedBox(
                            height: 12,
                            width: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                          )
                        : const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      isSaving ? 'Syncing...' : 'Safe & Synced',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: UIConstants.s2PricingSpace),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                key: state.mrpKey,
                child: CustomTextField(
                  controller: state.mrpController,
                  focusNode: state.mrpFocus,
                  label: 'MRP',
                  hint: '5000',
                  keyboardType: TextInputType.number,
                  hasError: state.mrpError,
                  verticalPadding: 7,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                key: state.discountKey,
                child: CustomTextField(
                  controller: state.discountAmountController,
                  focusNode: state.discountFocus,
                  label: 'Discount',
                  hint: '1000',
                  keyboardType: TextInputType.number,
                  hasError: state.discountError,
                  verticalPadding: 7,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CustomTextField(
                controller: state.finalPriceController,
                label: 'Final',
                hint: '0',
                keyboardType: TextInputType.number,
                readOnly: true,
                verticalPadding: 7,
              ),
            ),
          ],
        ),
        if (state.discountWarning)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade400),
                const SizedBox(width: 4),
                Text(
                  'Warning: Maximum discount allowed is 50% of MRP',
                  style: TextStyle(
                    color: Colors.orange.shade400,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLanguageSupportSection(BuildContext context) {
    return Column(
      children: [
        Container(
          key: state.languageKey,
          child: _buildDropdown(
            context,
            label: 'Course Language',
            hint: 'Select Language',
            value: state.selectedLanguage,
            items: CourseStateManager.languages,
            hasError: state.languageError,
            prefixIcon: Icons.language,
            onChanged: (v) {
              if (state.selectedLanguage == v) {
                state.selectedLanguage = null;
              } else {
                state.selectedLanguage = v;
                state.languageError = false;
              }
              state.updateState();
              logic.draftManager.saveCourseDraft();
            },
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                key: state.courseModeKey,
                child: _buildDropdown(
                  context,
                  label: 'Course Mode',
                  hint: 'Select Mode',
                  hintFontSize: 11,
                  value: state.selectedCourseMode,
                  items: CourseStateManager.courseModes,
                  hasError: state.courseModeError,
                  onChanged: (v) {
                    if (state.selectedCourseMode == v) {
                      state.selectedCourseMode = null;
                    } else {
                      state.selectedCourseMode = v;
                      state.courseModeError = false;
                    }
                    state.updateState();
                    logic.draftManager.saveCourseDraft();
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                key: state.supportTypeKey,
                child: _buildDropdown(
                  context,
                  label: 'Support Type',
                  hint: 'Select Type',
                  hintFontSize: 11,
                  value: state.selectedSupportType,
                  items: CourseStateManager.supportTypes,
                  hasError: state.supportTypeError,
                  onChanged: (v) {
                    if (state.selectedSupportType == v) {
                      state.selectedSupportType = null;
                    } else {
                      state.selectedSupportType = v;
                      state.supportTypeError = false;
                    }
                    state.updateState();
                    logic.draftManager.saveCourseDraft();
                  },
                ),
              ),
            ),
          ],
        ),
        if (state.selectedSupportType == 'WhatsApp Group') ...[
          const SizedBox(height: 12),
          Container(
            key: state.whatsappKey,
            child: CustomTextField(
              controller: state.whatsappController,
              label: 'Support WP Group Link',
              hint: 'Paste WhatsApp Group Invite Link',
              icon: Icons.link,
              keyboardType: TextInputType.url,
              hasError: state.wpGroupLinkError,
              onChanged: (v) {
                logic.draftManager.saveCourseDraft();
                logic.checkUrlValidity(v, isWhatsapp: true);
              },
              suffixWidget: state.isWpChecking
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : state.isWpValid
                       ? const Icon(Icons.check_circle, color: Colors.green)
                       : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildValiditySection(BuildContext context) {
    return Container(
      key: state.validityKey,
      child: DropdownButtonFormField<int>(
        isExpanded: true,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16),
        initialValue: state.courseValidityDays,
        hint: const Text('Select Validity'),
        decoration: _dropdownDecoration(context, 'Course Validity', state.validityError, prefix: Icons.history_toggle_off),
        items: const [
          DropdownMenuItem(value: 0, child: Text('Lifetime Access')),
          DropdownMenuItem(value: 184, child: Text('6 Months')),
          DropdownMenuItem(value: 365, child: Text('1 Year')),
          DropdownMenuItem(value: 730, child: Text('2 Years')),
          DropdownMenuItem(value: 1095, child: Text('3 Years')),
        ],
        onChanged: (v) {
          if (state.courseValidityDays == v) {
            state.courseValidityDays = null;
          } else {
            state.courseValidityDays = v;
            state.validityError = false;
          }
          state.updateState();
          logic.draftManager.saveCourseDraft();
        },
      ),
    );
  }

  Widget _buildCertificateSection(BuildContext context) {
    return Column(
      key: state.certificateKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Enable Certificate',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            state.hasCertificate
                ? 'Certificate will be issued on completion'
                : 'No certificate for this course',
          ),
          value: state.hasCertificate,
          onChanged: (v) {
            state.hasCertificate = v;
            state.updateState();
            logic.draftManager.saveCourseDraft();
          },
          activeThumbColor: AppTheme.primaryColor,
        ),
        if (state.hasCertificate) ...[
          const SizedBox(height: 24),
          const Text(
            'Upload Certificate Design',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload PDF File (A4 Landscape)',
            style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          PdfUploader(
            file: state.certificate1File,
            label: 'Tap to upload Certificate PDF',
            onTap: () => logic.pickCertificatePdf(context, showWarning),
            onRemove: state.certificate1File != null ? () {
              state.certificate1File = null;
              state.updateState();
              logic.draftManager.saveCourseDraft();
            } : null,
            onView: state.certificate1File != null ? () => _showPdfViewer(context) : null,
          ),
          if (state.certError && state.certificate1File == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Upload at least one design',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildBigScreenToggle(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Watch on Big Screens',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Allow access via Web/Desktop'),
          value: state.isBigScreenEnabled,
          onChanged: (v) {
            state.isBigScreenEnabled = v;
            state.updateState();
            logic.draftManager.saveCourseDraft();
          },
          activeThumbColor: AppTheme.primaryColor,
        ),
        if (state.isBigScreenEnabled) ...[
          const SizedBox(height: 12),
          Container(
            key: state.bigScreenKey,
            child: CustomTextField(
              controller: state.websiteUrlController,
              label: 'Website Login URL',
              hint: 'https://yourwebsite.com/login',
              icon: Icons.language,
              onChanged: (v) {
                logic.draftManager.saveCourseDraft();
                logic.checkUrlValidity(v, isWhatsapp: false);
              },
              suffixWidget: state.isWebChecking
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : state.isWebValid
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
              hasError: state.bigScreenUrlError,
            ),
          ),
        ],
      ],
    );
  }

  void _showPdfViewer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 800,
          height: 600,
          child: Column(
            children: [
              AppBar(
                title: Text(state.certificate1File!.path.split('/').last),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
              ),
              Expanded(
                child: SfPdfViewer.file(state.certificate1File!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(BuildContext context, String label, bool hasError, {IconData? prefix}) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(vertical: UIConstants.inputVerticalPadding, horizontal: 16),
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      prefixIcon: prefix != null ? Icon(prefix, size: 20) : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UIConstants.globalRadius),
        borderSide: BorderSide(
          color: hasError ? Colors.red : Theme.of(context).dividerColor.withValues(alpha: UIConstants.borderOpacity),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UIConstants.globalRadius),
        borderSide: BorderSide(
          color: hasError ? Colors.red : AppTheme.primaryColor,
          width: 2,
        ),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(UIConstants.globalRadius)),
      filled: true,
      fillColor: AppTheme.primaryColor.withValues(alpha: UIConstants.fillOpacity),
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String label,
    String? hint,
    required String? value,
    required List<String> items,
    required bool hasError,
    double hintFontSize = 13,
    IconData? prefixIcon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16),
      initialValue: value,
      hint: Text(
        hint ?? 'Select $label',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
          fontSize: hintFontSize,
          fontWeight: FontWeight.normal,
        ),
      ),
      decoration: _dropdownDecoration(context, label, hasError, prefix: prefixIcon),
      items: items.map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }
}
