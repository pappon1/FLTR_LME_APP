import 'package:flutter/material.dart';
import '../../../../../utils/app_theme.dart';
import '../../local_logic/state_manager.dart';

class CourseAppBar extends StatelessWidget implements PreferredSizeWidget {
  final CourseStateManager state;
  final int currentStep;
  final VoidCallback onCancelSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onBulkCopy;
  final VoidCallback onBulkDelete;
  final VoidCallback onAddContent;
  final VoidCallback onCancelDrag;

  const CourseAppBar({
    super.key,
    required this.state,
    required this.currentStep,
    required this.onCancelSelection,
    required this.onSelectAll,
    required this.onBulkCopy,
    required this.onBulkDelete,
    required this.onAddContent,
    required this.onCancelDrag,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isDragModeActive) {
      return AppBar(
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onCancelDrag,
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Drag and Drop Mode',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        elevation: 2,
      );
    }

    if (state.isSelectionMode) {
      return AppBar(
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onCancelSelection,
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${state.selectedIndices.length} Selected',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: TextButton(
              onPressed: onSelectAll,
              child: Text(
                state.selectedIndices.length == state.courseContents.length ? 'Unselect' : 'All',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: onBulkCopy,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: onBulkDelete,
          ),
        ],
        elevation: 2,
      );
    }

    return AppBar(
      title: const Text('Add Course', style: TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      elevation: 0,
      actions: [
        if (currentStep == 2)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: InkWell(
                onTap: onAddContent,
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
