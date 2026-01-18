import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoBottomControls extends StatelessWidget {
  final bool isLocked;
  final bool isLandscape;
  final bool isUnlockControlsVisible;
  final double playbackSpeed;
  final String currentQuality;
  final String? activeTray;
  
  final VoidCallback onToggleTraySpeed;
  final VoidCallback? onToggleTrayQuality;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback onLockTap;
  final VoidCallback onDoubleLockTap;
  final VoidCallback onOrientationTap;
  
  final VoidCallback onResetSpeed;
  final VoidCallback onResetQuality;

  const VideoBottomControls({
    super.key,
    required this.isLocked,
    required this.isLandscape,
    required this.isUnlockControlsVisible,
    required this.playbackSpeed,
    required this.currentQuality,
    this.activeTray,
    required this.onToggleTraySpeed,
    this.onToggleTrayQuality,
    this.onTogglePlaylist,
    required this.onLockTap,
    required this.onDoubleLockTap,
    required this.onOrientationTap,
    required this.onResetSpeed,
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

        // Playlist Button (only if onTogglePlaylist is provided)
        if (onTogglePlaylist != null)
          _buildAnimatedControl(
            isVisible: !isLocked,
            child: _buildControlIcon(
              Icons.playlist_play,
              'List',
              onTogglePlaylist!,
              isActive: false,
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
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = isDark ? Colors.white : Colors.black87;

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
                        color: color,
                        size: isLocked ? 44 : 22,
                      ),
                    ),
                    const SizedBox(height: 3),
                      if (!isLocked)
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Lock",
                            style: TextStyle(color: Colors.white, fontSize: 10), // Fixed color access since we are in builder but using local var 'color'
                          ),
                        ),
                    if (isLocked && isUnlockControlsVisible)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Double tap\nto unlock",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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
    );
  }

  Widget _buildControlIcon(IconData icon, String label, VoidCallback? onTap,
      {bool isActive = false, VoidCallback? onReset}) {
    
    // In BuildContext isn't readily available in helper method if not passed, 
    // but better to pass or use Builder. 
    // Since this is a stateless widget method, we can't access context easily unless we change signature.
    // Let's change the call sites to pass context or use Builder.
    // Actually, Cleaner way: Move this method to build() or make it accept context.
    
    // Changing signature:
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = isActive 
            ? const Color(0xFF22C55E) 
            : ((isLandscape || isDark) ? Colors.white : Colors.black87);
            
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
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}
