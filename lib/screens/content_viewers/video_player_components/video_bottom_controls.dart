import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoBottomControls extends StatelessWidget {
  final bool isLocked;
  final bool isLandscape;
  final bool isUnlockControlsVisible;
  final double playbackSpeed;
  final String currentSubtitle;
  final String currentQuality;
  final String? activeTray;
  
  final VoidCallback onToggleTraySpeed;
  final VoidCallback onToggleTraySubtitle;
  final VoidCallback onToggleTrayQuality;
  final VoidCallback onLockTap;
  final VoidCallback onDoubleLockTap;
  final VoidCallback onOrientationTap;
  
  final VoidCallback onResetSpeed;
  final VoidCallback onResetSubtitle;
  final VoidCallback onResetQuality;

  const VideoBottomControls({
    super.key,
    required this.isLocked,
    required this.isLandscape,
    required this.isUnlockControlsVisible,
    required this.playbackSpeed,
    required this.currentSubtitle,
    required this.currentQuality,
    this.activeTray,
    required this.onToggleTraySpeed,
    required this.onToggleTraySubtitle,
    required this.onToggleTrayQuality,
    required this.onLockTap,
    required this.onDoubleLockTap,
    required this.onOrientationTap,
    required this.onResetSpeed,
    required this.onResetSubtitle,
    required this.onResetQuality,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Speed
        _buildAnimatedControl(
          isVisible: !isLocked, 
          child: _buildControlIcon(
            Icons.speed,
            "${playbackSpeed.toStringAsFixed(2)}x",
            onToggleTraySpeed,
            isActive: activeTray == 'speed' || playbackSpeed != 1.0,
            onReset: onResetSpeed,
          ),
        ),

        // Subtitle
        _buildAnimatedControl(
          isVisible: !isLocked,
          child: _buildControlIcon(
            Icons.closed_caption,
            currentSubtitle == "Off" ? "Subtitle" : currentSubtitle,
            onToggleTraySubtitle,
            isActive: activeTray == 'subtitle' || currentSubtitle != 'Off',
            onReset: onResetSubtitle,
          ),
        ),

        // Settings / Quality
        _buildAnimatedControl(
          isVisible: !isLocked,
          child: _buildControlIcon(
            Icons.settings,
            currentQuality,
            onToggleTrayQuality,
            isActive: activeTray == 'quality' || currentQuality != "Auto",
            onReset: onResetQuality,
          ),
        ),

        // Lock Button
        _buildLockButton(),

        // Orientation Toggle
        _buildAnimatedControl(
          isVisible: !isLocked,
          child: _buildControlIcon(
            isLandscape ? Icons.fullscreen_exit : Icons.fullscreen,
            isLandscape ? "Portrait" : "Landscape",
            onOrientationTap,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedControl({required bool isVisible, required Widget child}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: child,
      ),
    );
  }

  Widget _buildLockButton() {
    if (!isLandscape) {
      // Portrait Mode - Simplified Toggle logic
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isLocked ? (isUnlockControlsVisible ? 1.0 : 0.0) : 1.0,
        child: IgnorePointer(
          ignoring: isLocked && !isUnlockControlsVisible,
          child: GestureDetector(
            onTap: onLockTap,
            onDoubleTap: isLocked ? onDoubleLockTap : null,
            behavior: HitTestBehavior.translucent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isLocked ? Icons.lock : Icons.lock_open,
                    color: Colors.white,
                    size: isLocked ? 44 : 22,
                  ),
                ),
                const SizedBox(height: 3),
                if (!isLocked)
                  const Text(
                    "Lock",
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                if (isLocked && isUnlockControlsVisible)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      "Double tap\nto unlock",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
              ],
            ),
          ),
        ),
      );
    } else {
      // Landscape Lock Button
      return _buildControlIcon(
        isLocked ? Icons.lock : Icons.lock_outline,
        "Lock",
        onLockTap,
      );
    }
  }

  Widget _buildControlIcon(IconData icon, String label, VoidCallback onTap,
      {bool isActive = false, VoidCallback? onReset}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      onLongPress: () {
        if (onReset != null) {
          HapticFeedback.heavyImpact();
          onReset();
        }
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? const Color(0xFF22C55E) : Colors.white, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
