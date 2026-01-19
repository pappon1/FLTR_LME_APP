import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../utils/app_theme.dart';

class CourseContentListItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isDragMode;
  final VoidCallback onTap;
  final VoidCallback onToggleSelection;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onStartHold;
  final VoidCallback onCancelHold;
  final VoidCallback onRename;
  final VoidCallback onRemove;
  final VoidCallback? onAddThumbnail;

  const CourseContentListItem({
    super.key,
    required this.item,
    required this.index,
    required this.isSelected,
    required this.isSelectionMode,
    required this.isDragMode,
    required this.onTap,
    required this.onToggleSelection,
    required this.onEnterSelectionMode,
    required this.onStartHold,
    required this.onCancelHold,
    required this.onRename,
    required this.onRemove,
    this.onAddThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (item['type']) {
      case 'folder':
        icon = Icons.folder;
        color = Colors.orange;
        break;
      case 'video':
        icon = Icons.video_library;
        color = Colors.red;
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.redAccent;
        break;
      case 'image':
        icon = Icons.image;
        color = Colors.purple;
        break;
      case 'zip':
        icon = Icons.folder_zip;
        color = Colors.blueGrey;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.blue;
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              tileColor: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey.shade200,
                      width: isSelected ? 2 : 1)),
              leading: Hero(
                tag: item['path'] ?? item['name'] + index.toString(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ),
              title: Text(item['name'],
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryColor : null),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: isSelectionMode
                  ? GestureDetector(
                      onTap: onToggleSelection,
                      child: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.primaryColor)
                          : const Icon(Icons.circle_outlined,
                              color: Colors.grey),
                    )
                  : const SizedBox(width: 48),
            ),
          ),
          if (!isSelectionMode && !isDragMode)
            Positioned(
              right: 0,
              top: 0,
              bottom: 12,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'remove') onRemove();
                  if (value == 'manage_thumbnail') onAddThumbnail?.call();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'rename',
                      child: Row(children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Rename')
                      ])),
                  const PopupMenuItem(
                      value: 'remove',
                      child: Row(children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Remove', style: TextStyle(color: Colors.red))
                      ])),
                  if (item['type'] == 'video')
                    const PopupMenuItem(
                      value: 'manage_thumbnail',
                      child: Row(children: [
                        Icon(Icons.image, size: 20),
                        SizedBox(width: 12),
                        Text('Thumbnail')
                      ]),
                    ),
                ],
              ),
            ),
          Positioned.fill(
            bottom: 12,
            child: isDragMode
                ? Row(
                    children: [
                      const SizedBox(width: 60), // Left Scroll Zone
                      Expanded(
                        child: ReorderableDragStartListener(
                          index: index,
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      const SizedBox(width: 60), // Right Scroll Zone
                    ],
                  )
                : Row(
                    children: [
                      // Left Zone: Tap & Hold for Drag
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (_) => onStartHold(),
                          onTapUp: (_) => onCancelHold(),
                          onTapCancel: () => onCancelHold(),
                          onTap: onTap,
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      // Right Zone: Long Press for Selection
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onLongPress: onEnterSelectionMode,
                          onTap: onTap,
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      const SizedBox(width: 48), // Spacing for menu button
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
