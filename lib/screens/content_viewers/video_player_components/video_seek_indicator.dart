import 'package:flutter/material.dart';

class VideoSeekIndicator extends StatelessWidget {
  final int value; // +10 or -10

  const VideoSeekIndicator({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isForward = value > 0;
    const bgColor = Colors.black45; // Always dark over video
    const contentColor = Colors.white; // Always white over video

    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForward ? Icons.fast_forward : Icons.fast_rewind,
              color: contentColor,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              "${isForward ? '+' : ''}$value s",
              style: TextStyle(
                color: contentColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
