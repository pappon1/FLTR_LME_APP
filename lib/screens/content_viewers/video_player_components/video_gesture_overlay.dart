import 'package:flutter/material.dart';

class VideoGestureOverlay extends StatelessWidget {
  final bool showBrightness;
  final bool showVolume;
  final double brightness;
  final double volume;

  const VideoGestureOverlay({
    super.key,
    required this.showBrightness,
    required this.showVolume,
    required this.brightness,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const contentColor = Colors.white; // Always white over video
    const bgColor = Colors.black45; // Fixed dark bg

    return Stack(
      children: [
        // Brightness Slider (Left)
        if (showBrightness)
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildSlider(
                icon: Icons.wb_sunny,
                value: brightness,
                activeColor: isDark ? Colors.white : Colors.orange,
                bgColor: bgColor,
                contentColor: contentColor,
              ),
            ),
          ),

        // Volume Slider (Right)
        if (showVolume)
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildSlider(
                icon: Icons.volume_up,
                value: volume,
                activeColor: const Color(0xFF22C55E),
                bgColor: bgColor,
                contentColor: contentColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSlider({
    required IconData icon,
    required double value,
    required Color activeColor,
    required Color bgColor,
    required Color contentColor,
  }) {
    return Container(
      width: 40,
      height: 160,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3.0),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(icon, color: contentColor, size: 20),
          ),
          Expanded(
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                  activeTrackColor: activeColor,
                  inactiveTrackColor: contentColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: value.clamp(0.0, 1.0),
                  onChanged: (v) {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

