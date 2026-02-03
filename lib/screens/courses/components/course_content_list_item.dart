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
  final VoidCallback? onToggleLock;
  final bool isReadOnly;

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
    this.onToggleLock,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMedia = item['type'] == 'video' || item['type'] == 'image';

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(3.0),
                border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Theme.of(context).dividerColor.withValues(alpha: 0.12),
                    width: isSelected ? 2 : 1),
              ),
              child: isMedia ? _buildMediaLayout(context) : _buildStandardLayout(context),
            ),
          ),


          if (!isReadOnly)
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
                        const SizedBox(width: 60), // Right Scroll Zone (increased for menu)
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
                        // Right Zone: Long Press for Selection (excluding 3-dot menu area)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onLongPress: onEnterSelectionMode,
                            onTap: onTap,
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                        // Exclude 3-dot menu area from overlay (48px width for icon button)
                        const SizedBox(width: 48),
                      ],
                    ),
            ),
            // Selection Checkcircle Overlay
            if (isSelectionMode)
              Positioned(
                right: 12,
                top: 12,
                child: GestureDetector(
                  onTap: onToggleSelection,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white, // Background for visibility
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                        : const Icon(Icons.circle_outlined, color: Colors.grey),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(BuildContext context) {
      IconData icon;
      Color color;
      switch (item['type']) {
        case 'folder':
          icon = Icons.folder;
          color = Colors.orange;
          break;
        case 'pdf':
          icon = Icons.picture_as_pdf;
          color = Colors.redAccent;
          break;
        case 'zip':
          icon = Icons.folder_zip;
          color = Colors.blueGrey;
          break;
        default:
          icon = Icons.insert_drive_file;
          color = Colors.blue;
      }

      const double size = 60.0; // Fixed size as per user request
      const double iconDisplaySize = size * 0.56; // Ratio 28/50 approx -> ~33.6

      return ListTile(
        onTap: isReadOnly
            ? onTap
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
        leading: Hero(
          tag: (item['path'] ?? item['name']) + index.toString() + (isReadOnly ? '_read' : ''),
          child: Container(
            width: size, 
            height: size, 
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4.0), 
            ),
            child: Icon(icon, color: color, size: iconDisplaySize), 
          ),
        ),
        title: Text(
          item['name'],
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected 
                ? AppTheme.primaryColor 
                : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
            fontSize: 14, 
            height: 1.2, 
          ),
        ),
        trailing: isReadOnly 
            ? Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade400)
            : (!isSelectionMode
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          onRename();
                          break;
                        case 'thumbnail':
                          onAddThumbnail?.call();
                          break;
                        case 'delete':
                          onRemove();
                          break;
                        case 'toggle_lock':
                          onToggleLock?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      final bool isLocked = item['isLocked'] ?? true;
                      return [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      if (onAddThumbnail != null && item['type'] == 'video')
                        const PopupMenuItem(
                          value: 'thumbnail',
                          child: Row(
                            children: [
                              Icon(Icons.image, size: 18),
                              SizedBox(width: 8),
                              Text('Thumbnail'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'toggle_lock',
                        child: Row(
                          children: [
                            Icon(isLocked ? Icons.lock_open : Icons.lock, size: 18),
                            const SizedBox(width: 8),
                            Text(isLocked ? 'Unlock' : 'Lock'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ];
                    },
                  ),
                  if (item['isLocked'] ?? true) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.lock, size: 16, color: Colors.orange), 
                  ],
                  ],
                )
                : null),
      );
  }

  Widget _buildMediaLayout(BuildContext context) {
    // YouTube Style List Layout: Left Thumbnail, Right Title
    final bool isImage = item['type'] == 'image';
    
    // Config: Image = 80x80 (1:1), Video = 120x68 (16:9)
    final double thumbWidth = isImage ? 80.0 : 120.0;
    final double thumbHeight = isImage ? 80.0 : 68.0;

    return InkWell(
      onTap: isReadOnly 
        ? onTap 
        : null,
      borderRadius: BorderRadius.circular(3.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          // 1. Left Thumbnail Section
          Hero(
            tag: (item['path'] ?? item['name']) + index.toString() + (isReadOnly ? '_read' : ''),
            child: Container(
              width: thumbWidth,
              height: thumbHeight,
              margin: const EdgeInsets.fromLTRB(12, 12, 0, 12), // Left margin
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Stack(
                children: [
                  // Media Preview
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildLeadingPreview(
                          isImage ? Icons.image : Icons.video_library,
                          Colors.grey,
                          constraints.maxWidth,
                          constraints.maxHeight
                        );
                      }
                    ),
                  ),

                  // Duration Badge (Video Only)
                  if (item['type'] == 'video')
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Builder(
                        builder: (context) {
                          final duration = item['duration']
                              ?? item['videoDuration']
                              ?? item['durationInSeconds']
                              ?? item['length']
                              ?? item['videoLength'];
                          
                          if (duration != null) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatDuration(duration),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // 2. Center Text Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12), // Gap between thumb and text
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.w600, 
                      color: isSelected 
                          ? AppTheme.primaryColor 
                          : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                      fontSize: 14,
                      height: 1.2, 
                    ),
                  ),
                  const SizedBox(height: 8), // Gap before tag
                  
                  // Bottom-aligned Type Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isImage ? Colors.blue.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: isImage ? Colors.blue.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                        width: 0.5
                      )
                    ),
                    child: Text(
                      isImage ? 'IMAGE' : 'VIDEO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isImage ? Colors.blue : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 3. Right 3-dot Menu or Lock Icon
            if (isReadOnly)
             Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade400)
             else if (!isSelectionMode)
             Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
              // Remove explicit padding to let Row/ListTile alignment handle it
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    onRename();
                    break;
                  case 'thumbnail':
                    onAddThumbnail?.call();
                    break;
                  case 'delete':
                    onRemove();
                    break;
                  case 'toggle_lock':
                    onToggleLock?.call();
                    break;
                }
              },
              itemBuilder: (context) {
                final bool isLocked = item['isLocked'] ?? true;
                return [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Rename'),
                    ],
                  ),
                ),
                if (onAddThumbnail != null && item['type'] == 'video')
                  const PopupMenuItem(
                    value: 'thumbnail',
                    child: Row(
                      children: [
                        Icon(Icons.image, size: 18),
                        SizedBox(width: 8),
                        Text('Thumbnail'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'toggle_lock',
                  child: Row(
                    children: [
                      Icon(isLocked ? Icons.lock_open : Icons.lock, size: 18),
                      const SizedBox(width: 8),
                      Text(isLocked ? 'Unlock' : 'Lock'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ];
              },
            ),
             if (item['isLocked'] ?? true) ...[
                 const SizedBox(width: 4),
                 const Icon(Icons.lock, size: 16, color: Colors.orange),
             ],
           ],
          ),
        ],
      ),
     ),
    );
  }
  
  Widget _buildLeadingPreview(IconData defaultIcon, Color defaultColor, double width, double height) {
    final String? pathStr = item['path']?.toString();
    final String? thumb = item['thumbnail']?.toString();

    if (item['type'] == 'video') {
      // Use VideoThumbnailWidget if pathStr is available, otherwise use a fallback
      if (pathStr != null && pathStr.isNotEmpty) {
        return Stack(
          children: [
            VideoThumbnailWidget(
              videoPath: pathStr,
              customThumbnailPath: thumb,
              width: width,
              height: height,
            ),
            Container(color: Colors.black12), // Slight overlay
          ],
        );
      } else if (thumb != null && thumb.isNotEmpty) {
        // Fallback to custom thumbnail if pathStr is missing but thumb is present
        final bool isNetwork = thumb.startsWith('http');
        return Stack(
          fit: StackFit.expand,
          children: [
            isNetwork
                ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.black))
                : Image.file(File(thumb), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: Colors.black)),

          ],
        );
      }
      // Default fallback for video if no path or thumbnail
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(color: Colors.black87),
          const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
        ]
      );
    }

    if (item['type'] == 'image' && pathStr != null && pathStr.isNotEmpty) {
       final bool isNetwork = pathStr.startsWith('http');
       try {
         return isNetwork
            ? Image.network(pathStr, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Center(child: Icon(defaultIcon, color: defaultColor, size: 48)))
            : Image.file(File(pathStr), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Center(child: Icon(defaultIcon, color: defaultColor, size: 48)));
       } catch (_) {
         return Center(child: Icon(defaultIcon, color: defaultColor, size: 48));
       }
    }

    // Default icon for other types or if media path is invalid
    return Center(child: Icon(defaultIcon, color: defaultColor, size: 48));
  }

  String _formatDuration(dynamic duration) {
    try {
      int totalSeconds;
      
      // Handle different duration formats
      if (duration is int) {
        totalSeconds = duration;
      } else if (duration is double) {
        totalSeconds = duration.toInt();
      } else if (duration is String) {
        // Check if it's already formatted (e.g., "05:30" or "1:05:30")
        if (duration.contains(':')) {
          final parts = duration.split(':');
          if (parts.length == 2) {
            // MM:SS format
            final minutes = int.tryParse(parts[0]) ?? 0;
            final seconds = int.tryParse(parts[1]) ?? 0;
            totalSeconds = (minutes * 60) + seconds;
          } else if (parts.length == 3) {
            // HH:MM:SS format
            final hours = int.tryParse(parts[0]) ?? 0;
            final minutes = int.tryParse(parts[1]) ?? 0;
            final seconds = int.tryParse(parts[2]) ?? 0;
            totalSeconds = (hours * 3600) + (minutes * 60) + seconds;
          } else {
            return duration; // Return as-is if unknown format
          }
        } else {
          // Try parsing as raw seconds string
          totalSeconds = int.tryParse(duration) ?? 0;
        }
      } else {
        return '';
      }

      if (totalSeconds <= 0) return '';

      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      final seconds = totalSeconds % 60;

      if (hours > 0) {
        return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      } else {
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }
}

