import 'dart:io';
import 'package:flutter/material.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/video_thumbnail_widget.dart';

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
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.0),
                  side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Theme.of(context).dividerColor.withValues(alpha: 0.12),
                      width: isSelected ? 2 : 1)),
              leading: Hero(
                tag: (item['path'] ?? item['name']) + index.toString(),
                child: Container(
                  width: item['type'] == 'video' ? 80 : 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildLeadingPreview(
                    icon, 
                    color, 
                    item['type'] == 'video' ? 80 : 44, 
                    44
                  ),
                ),
              ),
              title: Text(
                item['name'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primaryColor : null,
                  fontSize: 13,
                ),
              ),
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
                    borderRadius: BorderRadius.circular(3.0)),
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

  Widget _buildLeadingPreview(IconData defaultIcon, Color defaultColor, double width, double height) {
    final String? pathStr = item['path']?.toString();
    final String? thumb = item['thumbnail']?.toString();

    if (item['type'] == 'video' && pathStr != null) {
      return Stack(
        children: [
          VideoThumbnailWidget(
            videoPath: pathStr,
            customThumbnailPath: thumb,
            width: width,
            height: height,
          ),
          Container(color: Colors.black12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      );
    }

    if (item['type'] == 'image' && pathStr != null) {
       final bool isNetwork = pathStr.startsWith('http');
       try {
         return isNetwork 
            ? Image.network(pathStr, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(defaultIcon, color: defaultColor, size: 20))
            : Image.file(File(pathStr), width: width, height: height, fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(defaultIcon, color: defaultColor, size: 20));
       } catch (_) {
         return Icon(defaultIcon, color: defaultColor, size: 20);
       }
    }

    return Icon(defaultIcon, color: defaultColor, size: 20);
  }
}

