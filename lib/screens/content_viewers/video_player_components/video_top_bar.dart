import 'package:flutter/material.dart';

class VideoPlayerTopBar extends StatelessWidget {
  final String title;
  final bool isLocked;
  final bool isVisible;
  final VoidCallback onBack;
  final bool isLandscape;

  const VideoPlayerTopBar({
    super.key,
    required this.title,
    required this.isLocked,
    required this.isVisible,
    required this.onBack,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // In landscape, we want it transparent to see the video
    final backgroundColor = isLandscape 
        ? Colors.transparent 
        : (isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white);
        
    final contentColor = (isLandscape || isDark) ? Colors.white : Colors.black87;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Container(
          color: backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Back Button (Hide if locked)
              Opacity(
                opacity: isLocked ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: isLocked,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: contentColor),
                    onPressed: onBack,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
