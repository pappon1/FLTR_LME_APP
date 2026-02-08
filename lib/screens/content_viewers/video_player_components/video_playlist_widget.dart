import 'package:flutter/material.dart';
import '../../../widgets/video_thumbnail_widget.dart';

class VideoPlaylistWidget extends StatefulWidget {
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
  State<VideoPlaylistWidget> createState() => _VideoPlaylistWidgetState();
}

class _VideoPlaylistWidgetState extends State<VideoPlaylistWidget> {
  late final ScrollController _scrollController;
  final double _itemHeight = 101.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Point 3: Auto-scroll to current item on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentIndex();
    });
  }

  @override
  void didUpdateWidget(VideoPlaylistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scrollToCurrentIndex();
    }
  }

  void _scrollToCurrentIndex() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      (widget.currentIndex * _itemHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return "00:00";
    if (duration is int) {
      final int minutes = duration ~/ 60;
      final int seconds = duration % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return duration.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      itemCount: widget.playlist.length,
      itemBuilder: (context, i) => _buildPlaylistItem(widget.playlist[i], i),
    );
  }

  Widget _buildPlaylistItem(Map<String, dynamic> item, int index) {
    final isPlaying = index == widget.currentIndex;
    final path = item['path'] as String?;
    final progress = widget.videoProgress[path] ?? 0.0;

    // Theme colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isPlaying
        ? const Color(0xFF22C55E)
        : (isDark ? Colors.white : Colors.black87);
    final subTextColor = isPlaying
        ? const Color(0xFF22C55E).withValues(alpha: 0.8)
        : (isDark ? Colors.white54 : Colors.black54);
    final thumbnailBg = isDark
        ? const Color(0xFF202020)
        : const Color(0xFFEEEEEE);

    return InkWell(
      onTap: () => widget.onVideoTap(index),
      child: Container(
        height: 85,
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
                    color: thumbnailBg,
                    borderRadius: BorderRadius.circular(3.0),
                    border: isPlaying
                        ? Border.all(color: const Color(0xFF22C55E), width: 2)
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      path != null
                          ? Positioned.fill(
                              child: VideoThumbnailWidget(
                                videoPath: path,
                                customThumbnailPath: item['thumbnail'],
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: isDark ? Colors.white24 : Colors.black12,
                                size: 32,
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
                  const Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Color(0xFF22C55E),
                        size: 30,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['name'] ?? 'Unknown',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: subTextColor),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(item['duration']),
                        style: TextStyle(color: subTextColor, fontSize: 11),
                      ),
                      if (progress > 0.9) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle,
                          size: 12,
                          color: Color(0xFF22C55E),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "Watched",
                          style: TextStyle(
                            color: Color(0xFF22C55E),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
