import 'dart:ui';
import 'package:flutter/material.dart';

class VideoTray extends StatelessWidget {
  final String activeTray;
  final List<String> items;
  final String currentSelection;
  final double playbackSpeed;
  final bool isDraggingSpeedSlider;
  final Function(String) onItemSelected;
  final Function(double) onSpeedChanged;
  final VoidCallback onClose;
  final VoidCallback onInteraction;

  final bool isLandscape;
  
  const VideoTray({
    super.key,
    required this.activeTray,
    required this.items,
    required this.currentSelection,
    required this.playbackSpeed,
    required this.isDraggingSpeedSlider,
    required this.onItemSelected,
    required this.onSpeedChanged,
    required this.onClose,
    required this.onInteraction,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    // Check theme manually since parent resets scaffold color
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final forceDark = isLandscape || isDark;
    
    final bgColor = forceDark ? Colors.black.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95);
    final borderColor = forceDark ? Colors.white12 : Colors.black12;
    final closeBg = forceDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
    final closeIcon = forceDark ? Colors.white : Colors.black87;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Listener(
          onPointerDown: (_) => onInteraction(),
          onPointerMove: (_) => onInteraction(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: isDark ? [] : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 30),
                  child: _buildContent(context, isDark, forceDark),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: onClose,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: closeBg, shape: BoxShape.circle),
                        child: Icon(Icons.close, color: closeIcon, size: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, bool forceDark) {
    if (activeTray == 'speed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSpeedPicker(context, isDark, forceDark),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF22C55E),
              inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
              thumbColor: isDark ? Colors.white : Colors.black87,
              trackHeight: 2,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: isDraggingSpeedSlider ? 9 : 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: playbackSpeed,
              min: 0.5,
              max: 3.0,
              divisions: 50,
              onChanged: onSpeedChanged,
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final isSelected = item == currentSelection;
          return GestureDetector(
            onTap: () => onItemSelected(item),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF22C55E) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.grey),
              ),
              child: Text(
                item,
                style: TextStyle(
                  color: isSelected ? Colors.white : (forceDark ? Colors.white : Colors.black87),
                  fontSize: 11,
                  fontWeight: FontWeight.w500
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSpeedPicker(BuildContext context, bool isDark, bool forceDark) {
    return PopupMenuButton<double>(
      initialValue: playbackSpeed,
      offset: const Offset(0, 40),
      tooltip: 'Playback Speed',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      onSelected: onSpeedChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${playbackSpeed.toStringAsFixed(2)}x",
              style: TextStyle(
                color: forceDark ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.bold
              ),
            ),
            Icon(Icons.arrow_drop_down, color: forceDark ? Colors.white : Colors.black87, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => [0.5, 1.0, 1.25, 1.5, 2.0, 3.0]
          .map((s) => PopupMenuItem<double>(
                value: s,
                height: 32,
                child: Text(
                  "${s}x",
                  style: TextStyle(
                    color: playbackSpeed == s ? const Color(0xFF22C55E) : (forceDark ? Colors.white : Colors.black87),
                    fontSize: 13,
                    fontWeight: playbackSpeed == s ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              )).toList(),
    );
  }
}
