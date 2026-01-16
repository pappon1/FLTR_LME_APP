import 'package:flutter/material.dart';

class VideoCenterControls extends StatelessWidget {
  final bool isPlaying;
  final bool isVisible;
  final VoidCallback onPlayPause;
  final Function(int) onSeek;
  final double iconSize;

  const VideoCenterControls({
    super.key,
    required this.isPlaying,
    required this.isVisible,
    required this.onPlayPause,
    required this.onSeek,
    this.iconSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1.0 : 0.0,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Replay 10s
              _buildControlButton(
                icon: Icons.replay_10,
                onTap: () => onSeek(-10),
                size: iconSize * 0.875,
              ),
              const SizedBox(width: 24),

              // Play/Pause
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 1),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Forward 10s
              _buildControlButton(
                icon: Icons.forward_10,
                onTap: () => onSeek(10),
                size: iconSize * 0.875,
              ),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
