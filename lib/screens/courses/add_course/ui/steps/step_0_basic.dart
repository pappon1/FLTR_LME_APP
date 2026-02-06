import 'package:flutter/material.dart';
import '../../../../../utils/app_theme.dart';
import '../ui_constants.dart';
import '../../local_logic/state_manager.dart';
import '../../local_logic/step0_logic.dart';
import '../components/collapsing_step_indicator.dart';
import '../components/text_field.dart';

class Step0BasicWidget extends StatelessWidget {
  final CourseStateManager state;
  final Step0Logic logic;
  final Widget navButtons;
  final Function(String) showWarning;

  const Step0BasicWidget({
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
            const SliverPersistentHeader(
              delegate: CollapsingStepIndicator(
                currentStep: 0,
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
                          'Create New Course',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: UIConstants.labelFontSize + 2,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => logic.clearBasicDraft(context),
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
                    ValueListenableBuilder<bool>(
                      valueListenable: state.isSavingDraftNotifier,
                      builder: (context, isSaving, _) {
                        return Visibility(
                          visible: state.hasContent,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: Container(
                            margin: EdgeInsets.zero,
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                isSaving
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
                                  isSaving ? 'Syncing...' : 'Safe & Synced',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: UIConstants.s1HeaderSpace),
                    // 1. Image
                    const Text(
                      'Course Cover (16:9 Size)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: UIConstants.labelFontSize,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      key: state.thumbnailKey,
                      onTap: () => logic.pickImage(context, showWarning),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(UIConstants.globalRadius),
                            border: Border.all(
                              color: state.thumbnailImage == null
                                  ? (state.thumbnailError
                                      ? Colors.red.withValues(alpha: 0.8)
                                      : Theme.of(context).dividerColor.withValues(alpha: UIConstants.borderOpacity))
                                  : AppTheme.primaryColor.withValues(alpha: 0.5),
                              width: (state.thumbnailImage == null && state.thumbnailError) ? 2 : (state.thumbnailImage == null ? 1 : 2),
                              style: BorderStyle.solid,
                            ),
                            boxShadow: state.thumbnailImage == null
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                            image: state.thumbnailImage != null
                                ? DecorationImage(
                                    image: FileImage(state.thumbnailImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: state.thumbnailImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_rounded,
                                      size: 48,
                                      color: AppTheme.primaryColor.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Select 16:9 Image',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: UIConstants.s1ImageSpace),
    
                    // 2. Title
                    Container(
                      key: state.titleKey,
                      child: CustomTextField(
                        controller: state.titleController,
                        focusNode: state.titleFocus,
                        label: 'Course Title',
                        hint: 'Advanced Mobile Repairing',
                        icon: Icons.title,
                        maxLength: 40,
                        hasError: state.titleError,
                      ),
                    ),
    
                    // 3. Description
                    Container(
                      key: state.descKey,
                      child: CustomTextField(
                        controller: state.descController,
                        focusNode: state.descFocus,
                        label: 'Description',
                        hint: 'Explain what students will learn...',
                        maxLines: 5,
                        alignTop: true,
                        hasError: state.descError,
                      ),
                    ),
    
                    // 5. Category & Type
                    Container(
                      key: state.categoryKey,
                      child: Row(
                        children: [
                        Expanded(
                          child: _buildDropdown(
                            context,
                            label: 'Category',
                            value: state.selectedCategory,
                            items: CourseStateManager.categories,
                            hasError: state.categoryError,
                            onChanged: (v) {
                              if (state.selectedCategory == v) {
                                state.selectedCategory = null;
                              } else {
                                state.selectedCategory = v;
                                state.categoryError = false;
                              }
                              logic.draftManager.saveCourseDraft();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdown(
                            context,
                            label: 'Course Type',
                            hint: 'Select Type',
                            value: state.difficulty,
                            items: CourseStateManager.difficultyLevels,
                            hasError: state.difficultyError,
                            onChanged: (v) {
                              if (state.difficulty == v) {
                                state.difficulty = null;
                              } else {
                                state.difficulty = v;
                                state.difficultyError = false;
                              }
                              state.updateState();
                              logic.draftManager.saveCourseDraft();
                            },
                          ),
                        ),
                      ],
                    ),
                    ),
                    const SizedBox(height: 20),
    
                    const SizedBox(height: 20),
    
                    Container(
                      key: state.batchDurationKey,
                      child: _buildDropdownInt(
                        context,
                        label: 'New Badge Duration',
                      hint: 'Select Duration',
                      value: state.newBatchDurationDays,
                      items: {30: '1 Month', 60: '2 Months', 90: '3 Months'},
                      hasError: state.batchDurationError,
                      prefixIcon: Icons.timer_outlined,
                      onChanged: (v) {
                        if (state.newBatchDurationDays == v) {
                          state.newBatchDurationDays = null;
                        } else {
                          state.newBatchDurationDays = v;
                          state.batchDurationError = false;
                        }
                        logic.draftManager.saveCourseDraft();
                      },
                    ),
                    ),
    
                    const SizedBox(height: 20),
    
                    // 6. Highlights Section
                    Container(
                      key: state.highlightsKey,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Highlights',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          TextButton.icon(
                            onPressed: logic.addHighlight,
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (state.highlightControllers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          state.highlightsError ? 'Please add at least one highlight *' : 'No highlights added.',
                          style: TextStyle(
                            color: state.highlightsError ? Colors.red : Colors.grey,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontWeight: state.highlightsError ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      )
                    else
                      ...state.highlightControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final controller = entry.value;
                          return Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CustomTextField(
                                controller: controller,
                                label: 'Highlight',
                                hint: 'Practical Chip Level Training',
                                hasError: state.highlightsError && controller.text.trim().isEmpty,
                                onChanged: (_) => logic.draftManager.saveCourseDraft(),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                onPressed: () => logic.removeHighlight(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        );
                      }),
    
                    // 7. FAQs Section
                    Container(
                      key: state.faqsKey,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'FAQs',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          TextButton.icon(
                            onPressed: logic.addFAQ,
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (state.faqControllers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          state.faqsError ? 'Please add at least one FAQ *' : 'No FAQs added.',
                          style: TextStyle(
                            color: state.faqsError ? Colors.red : Colors.grey,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontWeight: state.faqsError ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      )
                    else
                      ...state.faqControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final faq = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withValues(alpha: UIConstants.borderOpacity),
                            ),
                            borderRadius: BorderRadius.circular(UIConstants.globalRadius),
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: faq['q']!,
                                      label: 'Question',
                                      hint: 'e.g. Who can join this course?',
                                      hasError: state.faqsError && faq['q']!.text.trim().isEmpty,
                                      onChanged: (_) => logic.draftManager.saveCourseDraft(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => logic.removeFAQ(index),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ],
                              ),
                              CustomTextField(
                                controller: faq['a']!,
                                label: 'Answer',
                                hint: 'Anyone with basic mobile knowledge...',
                                bottomPadding: 0.0,
                                hasError: state.faqsError && faq['a']!.text.trim().isEmpty,
                                onChanged: (_) => logic.draftManager.saveCourseDraft(),
                              ),
                            ],
                          ),
                        );
                      }),
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
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String label,
    String? hint,
    required String? value,
    required List<String> items,
    required bool hasError,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      initialValue: value,
      hint: Text(
        hint ?? 'Select $label',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.normal,
        ),
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: UIConstants.inputVerticalPadding, horizontal: 16),
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.globalRadius),
        ),
        filled: true,
        fillColor: AppTheme.primaryColor.withValues(alpha: UIConstants.fillOpacity),
      ),
      items: items.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownInt(
    BuildContext context, {
    required String label,
    String? hint,
    required int? value,
    required Map<int, String> items,
    required bool hasError,
    IconData? prefixIcon,
    required void Function(int?) onChanged,
  }) {
    return DropdownButtonFormField<int>(
      style: const TextStyle(color: Colors.white, fontSize: 16),
      initialValue: value,
      hint: Text(
        hint ?? 'Select $label',
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
          fontSize: 13,
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
          borderSide: BorderSide(
            color: hasError ? Colors.red : AppTheme.primaryColor,
            width: 2,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.globalRadius),
        ),
        filled: true,
        fillColor: AppTheme.primaryColor.withValues(alpha: UIConstants.fillOpacity),
      ),
      items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      onChanged: onChanged,
    );
  }
}
