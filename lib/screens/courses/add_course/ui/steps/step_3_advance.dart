import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for formatters
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
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              delegate: CollapsingStepIndicator(
                currentStep: 3,
                isSelectionMode: false,
                isDragMode: false,
                brightness: Theme.of(context).brightness,
              ),
              pinned: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: UIConstants.screenPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Special Course Badge (Tag)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: state.specialTagController,
                      label: 'Badge Text',
                      hint: 'e.g. Special Offer, Best Seller',
                      icon: Icons.local_offer,
                      maxLength: 12, // Keeps design compact
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return newValue.copyWith(text: newValue.text.toUpperCase());
                        }),
                      ],
                      onChanged: (_) => draftManager.saveCourseDraft(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          [
                            'Special Offer',
                            'Best Seller',
                            'Trending',
                            'Limited Seats',
                          ].map((tag) {
                            return ActionChip(
                              label: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                state.specialTagController.text = tag;
                                draftManager.saveCourseDraft();
                              },
                              backgroundColor: AppTheme.primaryColor.withValues(
                                alpha: 0.05,
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // ✨ Special Tag Visibility
                    SwitchListTile(
                      title: const Text(
                        'Show Special Tag',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Display the 3D screwdriver tag on the course card',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      value: state.isSpecialTagVisible,
                      onChanged: (v) {
                        state.isSpecialTagVisible = v;
                        draftManager.saveCourseDraft();
                      },
                      activeThumbColor: AppTheme.primaryColor,
                      tileColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (state.isSpecialTagVisible) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: state.specialTagDurationDays,
                        decoration: InputDecoration(
                          labelText: 'Badge Visibility Duration',
                          prefixIcon: const Icon(Icons.timer),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              UIConstants.globalRadius,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 30, child: Text('1 Month')),
                          DropdownMenuItem(value: 60, child: Text('2 Months')),
                          DropdownMenuItem(value: 90, child: Text('3 Months')),
                          DropdownMenuItem(
                            value: 0,
                            child: Text('Always Visible (Lifetime)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            state.specialTagDurationDays = v;
                            draftManager.saveCourseDraft();
                          }
                        },
                      ),
                    ],

                    // 🎨 Handle Color Picker
                    if (state.isSpecialTagVisible) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Handle Color',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: CourseStateManager.tagColors.map((colorName) {
                          final isSelected = state.specialTagColor == colorName;
                          Color color;
                          switch (colorName) {
                            case 'Red':
                              color = const Color(0xFFD32F2F);
                              break;
                            case 'Green':
                              color = const Color(0xFF388E3C);
                              break;
                            case 'Pink':
                              color = const Color(0xFFC2185B);
                              break;
                            case 'Blue':
                            default:
                              color = const Color(0xFF1976D2);
                              break;
                          }

                          return GestureDetector(
                            onTap: () {
                              state.specialTagColor = colorName;
                              draftManager.saveCourseDraft();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 16),
                              width: isSelected ? 42 : 36,
                              height: isSelected ? 42 : 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color.withOpacity(0.8), color],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).cardColor
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  else
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Distribution Settings
                    const Text(
                      'Distribution Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text(
                        'Offline Downloads',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Allow students to download videos inside the app',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      value: state.isOfflineDownloadEnabled,
                      onChanged: (v) {
                        state.isOfflineDownloadEnabled = v;
                        draftManager.saveCourseDraft();
                      },
                      activeThumbColor: AppTheme.primaryColor,
                      tileColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          UIConstants.globalRadius,
                        ),
                        side: BorderSide(
                          color: Theme.of(context).dividerColor.withValues(
                            alpha: UIConstants.borderOpacity,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Publish Status
                    const Text(
                      'Publish Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      value: state.isPublished,
                      onChanged: (v) {
                        state.isPublished = v;
                        draftManager.saveCourseDraft();
                      },
                      activeThumbColor: Colors.green,
                      tileColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          UIConstants.globalRadius,
                        ),
                        side: BorderSide(
                          color: state.isPublished
                              ? Colors.green.withValues(alpha: 0.3)
                              : Theme.of(context).dividerColor.withValues(
                                  alpha: UIConstants.borderOpacity,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CourseReviewCard(state: state, onEditStep: onEditStep),
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
}
