import 'package:flutter/material.dart';

class VideoLockOverlay extends StatelessWidget {
  final bool isVisible;
  final String title;
  final VoidCallback onUnlock;
  final VoidCallback onInteraction;

  const VideoLockOverlay({
    super.key,
    required this.isVisible,
    required this.title,
    required this.onUnlock,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const contentColor = Colors.white; // Always white over video
    const scrimColor = Colors.black54; // Fixed dark background for visibility
    final iconBg = Colors.white.withValues(alpha: 0.1);
    const borderColor = Colors.white30;

    return Stack(
      children: [
        // Catch taps to show/hide the lock UI
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onInteraction,
            child: Container(color: Colors.transparent),
          ),
        ),
        
        IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isVisible ? 1.0 : 0.0,
            child: Stack(
              children: [
                // 1. Dim Overlay
                Positioned.fill(
                  child: Container(color: scrimColor),
                ),
                
                // 2. Title (Top Center)
                Positioned(
                  top: 40, 
                  left: 20, 
                  right: 20,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: contentColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      shadows: isDark ? [const Shadow(color: Colors.black, blurRadius: 4)] : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 3. Lock Icon (Center)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onDoubleTap: onUnlock,
                        onTap: onInteraction,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor),
                          ),
                          child: Icon(Icons.lock, size: 40, color: contentColor),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Instructions (Bottom)
                Positioned(
                  bottom: 60,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      "Double tap to unlock",
                      style: TextStyle(
                        color: contentColor.withValues(alpha: 0.7), 
                        fontSize: 16, 
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
