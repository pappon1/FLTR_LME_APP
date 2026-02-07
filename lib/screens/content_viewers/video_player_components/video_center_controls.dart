import 'package:flutter/material.dart';

class VideoCenterControls extends StatelessWidget {
  final bool isPlaying;
  final bool isVisible;
  final VoidCallback onPlayPause;
  final Function(int) onSeek;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final bool hasNext;
  final bool hasPrev;
  final double iconSize;

  const VideoCenterControls({
    super.key,
    required this.isPlaying,
    required this.isVisible,
    required this.onPlayPause,
    required this.onSeek,
    this.onNext,
    this.onPrev,
    this.hasNext = false,
    this.hasPrev = false,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const iconColor = Colors.white; // Always white over video
    const bgColor = Colors.black45; // Fixed dark background for visibility
    final borderColor = isDark ? Colors.white30 : Colors.black12;

    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1.0 : 0.0,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous
              if (onPrev != null) ...[
                IconButton(
                  onPressed: hasPrev ? onPrev : null,
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: hasPrev ? iconColor : Colors.white24,
                    size: iconSize * 1.2,
                  ),
                ),
                const SizedBox(width: 32),
              ],

              // Replay 10s
              _buildControlButton(
                icon: Icons.replay_10,
                onTap: () => onSeek(-10),
                size: iconSize * 0.875,
                color: iconColor,
                bgColor: bgColor,
              ),
              const SizedBox(width: 48),

              // Play/Pause
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: iconColor,
                    size: iconSize,
                  ),
                ),
              ),
              const SizedBox(width: 48),

              // Forward 10s
              _buildControlButton(
                icon: Icons.forward_10,
                onTap: () => onSeek(10),
                size: iconSize * 0.875,
                color: iconColor,
                bgColor: bgColor,
              ),

              if (onNext != null) ...[
                const SizedBox(width: 32),
                IconButton(
                  onPressed: hasNext ? onNext : null,
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: hasNext ? iconColor : Colors.white24,
                    size: iconSize * 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    required Color color,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}
