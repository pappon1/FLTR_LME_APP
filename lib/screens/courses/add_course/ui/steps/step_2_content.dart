import 'package:flutter/material.dart';
import '../ui_constants.dart';
import '../../local_logic/state_manager.dart';
import '../../local_logic/step2_logic.dart';
import '../../local_logic/content_manager.dart';
import '../components/collapsing_step_indicator.dart';
import '../components/course_content_list_item.dart';
import '../components/shimmer_list.dart';
import '../components/content_dialogs.dart';

class Step2ContentWidget extends StatelessWidget {
  final CourseStateManager state;
  final Step2Logic logic;
  final ContentManager contentManager;
  final Widget navButtons;
  final Function(Map<String, dynamic>, int) onContentTap;

  const Step2ContentWidget({
    super.key,
    required this.state,
    required this.logic,
    required this.contentManager,
    required this.navButtons,
    required this.onContentTap,
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
                currentStep: 2,
                isSelectionMode: state.isSelectionMode,
                isDragMode: state.isDragModeActive,
                brightness: Theme.of(context).brightness,
              ),
              pinned: true,
            ),
            SliverPadding(
              key: const ValueKey('step2_content_padding'),
              padding: EdgeInsets.only(
                left: UIConstants.screenPadding,
                right: UIConstants.screenPadding,
                top: (state.isSelectionMode || state.isDragModeActive) ? 16.0 : 0,
              ),
              sliver: state.isInitialLoading
                  ? const SliverToBoxAdapter(child: ShimmerList())
                  : state.courseContents.isEmpty
                      ? SliverToBoxAdapter(
                          key: const ValueKey('add_course_empty_state'),
                          child: Container(
                            height: 300,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  state.courseContentError ? 'Add at least one content to proceed *' : 'No content added yet',
                                  style: TextStyle(
                                    color: state.courseContentError ? Colors.red : Colors.grey.shade400,
                                    fontWeight: state.courseContentError ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverReorderableList(
                          key: const ValueKey('course_content_reorderable_list'),
                          itemCount: state.courseContents.length,
                          onReorder: logic.onReorder,
                          itemBuilder: (context, index) {
                            final item = state.courseContents[index];
                            final isSelected = state.selectedIndices.contains(index);
    
                            return CourseContentListItem(
                              key: ObjectKey(item),
                              item: item,
                              index: index,
                              isSelected: isSelected,
                              isSelectionMode: state.isSelectionMode,
                              isDragMode: state.isDragModeActive,
                              leftOffset: UIConstants.contentItemLeftOffset,
                              videoThumbTop: UIConstants.videoThumbTop,
                              videoThumbBottom: UIConstants.videoThumbBottom,
                              imageThumbTop: UIConstants.imageThumbTop,
                              imageThumbBottom: UIConstants.imageThumbBottom,
                              bottomSpacing: UIConstants.itemBottomSpacing,
                              menuOffset: UIConstants.menuOffset,
                              lockLeftOffset: UIConstants.lockLeftOffset,
                              lockTopOffset: UIConstants.lockTopOffset,
                              lockSize: UIConstants.lockSize,
                              videoLabelOffset: UIConstants.videoLabelOffset,
                              imageLabelOffset: UIConstants.imageLabelOffset,
                              pdfLabelOffset: UIConstants.pdfLabelOffset,
                              folderLabelOffset: UIConstants.folderLabelOffset,
                              tagLabelFontSize: UIConstants.tagLabelFontSize,
                              menuPanelOffsetDX: UIConstants.menuPanelDX,
                              menuPanelOffsetDY: UIConstants.menuPanelDY,
                              menuPanelWidth: UIConstants.menuPanelWidth,
                              menuPanelHeight: UIConstants.menuPanelHeight,
                              onTap: () => onContentTap(item, index),
                              onToggleSelection: () => logic.toggleSelection(index),
                              onEnterSelectionMode: () => logic.enterSelectionMode(index),
                              onStartHold: () => logic.startHoldTimer(logic.enterDragMode),
                              onCancelHold: logic.cancelHoldTimer,
                              onRename: () => ContentDialogs.showRenameDialog(
                                context: context,
                                initialName: item['name'],
                                onRename: (newName) {
                                  state.courseContents[index]['name'] = newName;
                                  state.updateState();
                                  logic.draftManager.saveCourseDraft();
                                },
                              ),
                              onToggleLock: () => logic.toggleLock(index),
                              onRemove: () => contentManager.confirmRemoveContent(context, index),
                              onAddThumbnail: () => ContentDialogs.showThumbnailManagerDialog(
                                context: context,
                                initialThumbnail: item['thumbnail'],
                                onSave: (newThumb) {
                                  state.courseContents[index]['thumbnail'] = newThumb;
                                  state.updateState();
                                  logic.draftManager.saveCourseDraft();
                                },
                              ),
                            );
                          },
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
}
