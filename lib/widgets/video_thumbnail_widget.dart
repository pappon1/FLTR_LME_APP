import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const VideoThumbnailWidget({
    super.key,
    required this.videoPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnailData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _thumbnailData = null;
    });

    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 256, // Optimized for list views
        quality: 50,
      );

      if (mounted) {
        setState(() {
          _thumbnailData = uint8list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      debugPrint("Error generating thumbnail: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black12,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasError || _thumbnailData == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[900],
        child: const Icon(Icons.videocam_off, color: Colors.white54),
      );
    }

    return Image.memory(
      _thumbnailData!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }
}
