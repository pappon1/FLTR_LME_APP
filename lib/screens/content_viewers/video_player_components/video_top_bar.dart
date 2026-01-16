import 'package:flutter/material.dart';

class VideoPlayerTopBar extends StatelessWidget {
  final String title;
  final bool isLocked;
  final bool isVisible;
  final VoidCallback onBack;

  const VideoPlayerTopBar({
    super.key,
    required this.title,
    required this.isLocked,
    required this.isVisible,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Container(
          color: Colors.black.withOpacity(0.4), // Slight shadow for visibility
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Back Button (Hide if locked)
              Opacity(
                opacity: isLocked ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: isLocked,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: onBack,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
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
