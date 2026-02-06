import 'package:flutter/material.dart';
import '../../../../../utils/app_theme.dart';
import '../ui_constants.dart';
import '../../local_logic/state_manager.dart';
import '../../local_logic/step1_logic.dart';
import '../components/collapsing_step_indicator.dart';
import '../components/text_field.dart';
import '../components/image_uploader.dart';

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
    return CustomScrollView(
      controller: state.scrollController,
      slivers: [
        const SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: 1,
            isSelectionMode: false,
            isDragMode: false,
          ),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: UIConstants.screenPadding),
          sliver: SliverToBoxAdapter(
            child: Column(
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
                      label: const Text(
                        'Clear Draft',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                      ),
                    ),
                  ],
                ),
                // Safe & Synced Badge with loading indicator
                Visibility(
                  visible: state.hasSetupContent,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3.0),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        state.isSavingDraft
                            ? const SizedBox(
                                height: 12,
                                width: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.green,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green,
                              ),
                        const SizedBox(width: 8),
                        Text(
                          state.isSavingDraft ? 'Syncing...' : 'Safe & Synced',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: UIConstants.s2HeaderSpace),
                const SizedBox(height: UIConstants.s2PricingSpace),
                // 1. Pricing
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                    const SizedBox(width: 8),
                    Expanded(
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
                const SizedBox(height: UIConstants.s2LanguageSpace),

                // 2. Language & Support
                _buildDropdown(
                  context,
                  label: 'Course Language',
                  hint: 'Select Language',
                  value: state.selectedLanguage,
                  items: ['Hindi', 'English', 'Bengali'],
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
                SizedBox(height: state.tightVerticalMode ? 0 : 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        context,
                        label: 'Course Mode',
                        hint: 'Select Mode',
                        hintFontSize: 11,
                        value: state.selectedCourseMode,
                        items: ['Recorded', 'Live Session'],
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        context,
                        label: 'Support Type',
                        hint: 'Select Type',
                        hintFontSize: 11,
                        value: state.selectedSupportType,
                        items: ['WhatsApp Group', 'No Support'],
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
                  ],
                ),
                if (state.selectedSupportType == 'WhatsApp Group') ...[
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: state.whatsappController,
                    label: 'Support WP Group Link',
                    hint: 'Paste WhatsApp Group Invite Link',
                    icon: Icons.link,
                    keyboardType: TextInputType.url,
                    hasError: state.wpGroupLinkError,
                    onChanged: (_) => logic.draftManager.saveCourseDraft(),
                  ),
                ],
                const SizedBox(height: UIConstants.s2ValiditySpace),

                // 3. Validity & Certificate
                _buildValiditySelector(context),
                const SizedBox(height: 24),
                _buildCertificateSettings(context),
                const SizedBox(height: UIConstants.certToBigScreenSpace),

                // 4. PC/Web Support
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
                  SizedBox(height: state.tightVerticalMode ? 0 : 12),
                  CustomTextField(
                    controller: state.websiteUrlController,
                    label: 'Website Login URL',
                    hint: 'https://yourwebsite.com/login',
                    icon: Icons.language,
                    onChanged: (_) => logic.draftManager.saveCourseDraft(),
                    hasError: state.bigScreenUrlError,
                  ),
                ],
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
  }

  Widget _buildValiditySelector(BuildContext context) {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      value: state.courseValidityDays,
      hint: const Text('Select Validity'),
      decoration: InputDecoration(
        labelText: 'Course Validity',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: const Icon(Icons.history_toggle_off),
        contentPadding: const EdgeInsets.symmetric(
          vertical: UIConstants.inputVerticalPadding,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.globalRadius),
          borderSide: BorderSide(
            color: state.validityError
                ? Colors.red
                : Theme.of(context).dividerColor.withValues(alpha: UIConstants.borderOpacity),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.globalRadius),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.globalRadius),
        ),
        filled: true,
        fillColor: AppTheme.primaryColor.withValues(alpha: UIConstants.fillOpacity),
      ),
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
    );
  }

  Widget _buildCertificateSettings(BuildContext context) {
    return Column(
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
            'Upload Two Certificate Designs',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Strictly 3508 x 2480 Pixels (A4 Landscape)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Design A',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: state.selectedCertSlot == 1
                            ? AppTheme.primaryColor
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        ImageUploader(
                          image: state.certificate1Image,
                          label: 'Box 1',
                          icon: Icons.upload_file,
                          onTap: () {
                            logic.pickCertificateImage(context, 1, showWarning);
                            // Auto-select logic is handled in logic or manual here
                            state.selectedCertSlot = 1; 
                            state.updateState();
                          },
                          aspectRatio: 1.414,
                        ),
                        if (state.selectedCertSlot == 1)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: ElevatedButton(
                            onPressed: () {
                              state.selectedCertSlot = 1;
                              state.updateState();
                              logic.draftManager.saveCourseDraft();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 0),
                              backgroundColor: state.selectedCertSlot == 1
                                  ? AppTheme.primaryColor
                                  : Theme.of(context).cardColor,
                            ),
                            child: Text(
                              'Select',
                              style: TextStyle(
                                fontSize: 10,
                                color: state.selectedCertSlot == 1
                                    ? Colors.white
                                    : Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Design B',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: state.selectedCertSlot == 2
                            ? AppTheme.primaryColor
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        ImageUploader(
                          image: state.certificate2Image,
                          label: 'Box 2',
                          icon: Icons.upload_file,
                          onTap: () {
                            logic.pickCertificateImage(context, 2, showWarning);
                            state.selectedCertSlot = 2;
                            state.updateState();
                          },
                          aspectRatio: 1.414,
                        ),
                        if (state.selectedCertSlot == 2)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: ElevatedButton(
                            onPressed: () {
                              state.selectedCertSlot = 2;
                              state.updateState();
                              logic.draftManager.saveCourseDraft();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 0),
                              backgroundColor: state.selectedCertSlot == 2
                                  ? AppTheme.primaryColor
                                  : Theme.of(context).cardColor,
                            ),
                            child: Text(
                              'Select',
                              style: TextStyle(
                                fontSize: 10,
                                color: state.selectedCertSlot == 2
                                    ? Colors.white
                                    : Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.certError && state.certificate1Image == null && state.certificate2Image == null)
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
      style: const TextStyle(color: Colors.white, fontSize: 16),
      value: value,
      hint: Text(
        hint ?? 'Select $label',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
          fontSize: hintFontSize,
          fontWeight: FontWeight.normal,
        ),
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: UIConstants.inputVerticalPadding, horizontal: 16),
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.globalRadius),
          borderSide: BorderSide(
            color: hasError ? Colors.red : Theme.of(context).dividerColor.withValues(alpha: UIConstants.borderOpacity),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.globalRadius),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(UIConstants.globalRadius)),
        filled: true,
        fillColor: AppTheme.primaryColor.withValues(alpha: UIConstants.fillOpacity),
      ),
      items: items.map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }
}
