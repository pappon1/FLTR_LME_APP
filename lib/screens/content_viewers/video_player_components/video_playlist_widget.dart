import 'package:flutter/material.dart';
import '../../../widgets/video_thumbnail_widget.dart';

class VideoPlaylistWidget extends StatelessWidget {
  final List<Map<String, dynamic>> playlist;
  final int currentIndex;
  final Map<String, double> videoProgress;
  final Function(int) onVideoTap;

  const VideoPlaylistWidget({
    super.key,
    required this.playlist,
    required this.currentIndex,
    required this.videoProgress,
    required this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: playlist.length,
      itemBuilder: (context, i) => _buildPlaylistItem(playlist[i], i),
    );
  }

  Widget _buildPlaylistItem(Map<String, dynamic> item, int index) {
    final isPlaying = index == currentIndex;
    final path = item['path'] as String?;
    final progress = videoProgress[path] ?? 0.0;

    return InkWell(
      onTap: () => onVideoTap(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            // Thumbnail with progress
            Stack(
              children: [
                Container(
                  width: 150,
                  height: 85,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: isPlaying
                        ? Border.all(color: const Color(0xFF22C55E), width: 2)
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      path != null
                          ? VideoThumbnailWidget(videoPath: path, fit: BoxFit.cover)
                          : Center(
                              child: Icon(
                                isPlaying ? Icons.equalizer : Icons.play_circle_outline,
                                color: isPlaying ? const Color(0xFF22C55E) : Colors.white,
                                size: 40,
                              ),
                            ),
                      // Progress Bar at the bottom
                      if (progress > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            color: Colors.white24,
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(color: Colors.red),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Color(0xFF22C55E), size: 30),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Title and duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'Unknown',
                    style: TextStyle(
                      color: isPlaying ? const Color(0xFF22C55E) : Colors.white,
                      fontSize: 15,
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 12, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        item['duration'] ?? "00:00",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      if (progress > 0.9) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle,
                            size: 12, color: Color(0xFF22C55E)),
                        const SizedBox(width: 4),
                        const Text(
                          "Watched",
                          style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
