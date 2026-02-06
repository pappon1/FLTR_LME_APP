import 'package:flutter/material.dart';
import '../../../../../utils/app_theme.dart';
import '../ui_constants.dart';
import '../../local_logic/state_manager.dart';
import '../../local_logic/draft_manager.dart';
import '../components/collapsing_step_indicator.dart';
import '../components/review_card.dart';
import '../components/text_field.dart';

class Step3AdvanceWidget extends StatelessWidget {
  final CourseStateManager state;
  final DraftManager draftManager;
  final Widget navButtons;
  final Function(int) onEditStep;

  const Step3AdvanceWidget({
    super.key,
    required this.state,
    required this.draftManager,
    required this.navButtons,
    required this.onEditStep,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverPersistentHeader(
          delegate: CollapsingStepIndicator(
            currentStep: 3,
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
                // Review Card
                CourseReviewCard(
                  state: state,
                  onEditStep: onEditStep,
                ),
                const SizedBox(height: 32),

                // 4.5 Special Badge/Tag
                const Text(
                  'Special Course Badge (Tag)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: state.specialTagController,
                  label: 'Badge Text',
                  hint: 'e.g. Special Offer, Best Seller',
                  icon: Icons.local_offer,
                  maxLength: 20,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    'Special Offer',
                    'Best Seller',
                    'Trending',
                    'Limited Seats',
                  ].map((tag) {
                    return ActionChip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        state.specialTagController.text = tag;
                        state.updateState();
                        draftManager.saveCourseDraft();
                      },
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.05),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // 5. Offline Download Toggle
                const Text(
                  'Distribution Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'Offline Downloads',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Allow students to download videos inside the app',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: state.isOfflineDownloadEnabled,
                  onChanged: (v) {
                    state.isOfflineDownloadEnabled = v;
                    state.updateState();
                    draftManager.saveCourseDraft();
                  },
                  activeThumbColor: AppTheme.primaryColor,
                  tileColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.globalRadius),
                    side: BorderSide(
                      color: Colors.grey.withOpacity(UIConstants.borderOpacity),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 6. Publish Status
                const Text(
                  'Publish Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(
                    state.isPublished
                        ? 'Course is Public'
                        : 'Course is Hidden (Draft)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    state.isPublished
                        ? 'Visible to all students on the app'
                        : 'Only visible to admins',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: state.isPublished,
                  onChanged: (v) {
                    state.isPublished = v;
                    state.updateState();
                    draftManager.saveCourseDraft();
                  },
                  activeThumbColor: Colors.green,
                  tileColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.globalRadius),
                    side: BorderSide(
                      color: state.isPublished
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey.withOpacity(UIConstants.borderOpacity),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
}
