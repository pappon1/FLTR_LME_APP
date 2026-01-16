import 'package:flutter/material.dart';

class VideoSeekIndicator extends StatelessWidget {
  final int value; // +10 or -10

  const VideoSeekIndicator({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final isForward = value > 0;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForward ? Icons.fast_forward : Icons.fast_rewind,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              "${isForward ? '+' : ''}$value s",
              style: const TextStyle(
                color: Colors.white,
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
