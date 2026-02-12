import 'dart:typed_data';
import 'dart:io' as java_io;
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/config_service.dart';
import '../services/bunny_cdn_service.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  final String? customThumbnailPath;

  const VideoThumbnailWidget({
    super.key,
    required this.videoPath,
    this.customThumbnailPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  // Point 5: Global Memory Cache with Eviction Strategy
  static final Map<String, Uint8List> _memoryCache = {};
  static final List<String> _cacheKeys = [];
  static const int _maxCacheSize = 100; // Keep last 100 thumbnails

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();

  static void _addToCache(String path, Uint8List data) {
    if (_memoryCache.containsKey(path)) return;
    if (_cacheKeys.length >= _maxCacheSize) {
      final oldKey = _cacheKeys.removeAt(0);
      _memoryCache.remove(oldKey);
    }
    _cacheKeys.add(path);
    _memoryCache[path] = data;
  }
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnailData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _checkCacheAndGenerate();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath ||
        oldWidget.customThumbnailPath != widget.customThumbnailPath) {
      _checkCacheAndGenerate();
    }
  }

  void _checkCacheAndGenerate() {
    // 1. Check Custom Thumbnail Path First
    if (widget.customThumbnailPath != null) {
      _loadCustomThumbnail();
      return;
    }

    // 2. Then check memory cache for generated ones
    if (VideoThumbnailWidget._memoryCache.containsKey(widget.videoPath)) {
      // LRU: Refresh position
      VideoThumbnailWidget._cacheKeys.remove(widget.videoPath);
      VideoThumbnailWidget._cacheKeys.add(widget.videoPath);

      setState(() {
        _thumbnailData = VideoThumbnailWidget._memoryCache[widget.videoPath];
        _isLoading = false;
        _hasError = false;
      });
    } else {
      _generateThumbnail();
    }
  }

  Future<void> _loadCustomThumbnail() async {
    if (widget.customThumbnailPath == null) return;

    final bool isNetwork = widget.customThumbnailPath!.startsWith('http');

    if (isNetwork) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    // Check if we already have it in memory (using path as key)
    if (VideoThumbnailWidget._memoryCache.containsKey(
      widget.customThumbnailPath!,
    )) {
      setState(() {
        _thumbnailData =
            VideoThumbnailWidget._memoryCache[widget.customThumbnailPath!];
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    try {
      final file = java_io.File(widget.customThumbnailPath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();

        // Cache it
        VideoThumbnailWidget._addToCache(widget.customThumbnailPath!, bytes);

        if (mounted) {
          setState(() {
            _thumbnailData = bytes;
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        // Fallback to generator if file missing
        _generateThumbnail();
      }
    } catch (e) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    if (!mounted) return;

    // NEVER try to generate thumbnails from network URLs using this plugin
    // as it is unreliable and causes IOException (status 0x80000000)
    final bool isNetwork = widget.videoPath.startsWith('http');
    if (isNetwork) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true; // Mark as error so we don't keep trying
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _thumbnailData = null;
    });

    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200, // Reduced further for memory optimization
        quality: 35, // Reduced quality for better performance
      );

      if (uint8list != null) {
        VideoThumbnailWidget._addToCache(widget.videoPath, uint8list);
      }

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
      // debugPrint("Error generating thumbnail: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.transparent,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          ),
        ),
      );
    }

    if (widget.customThumbnailPath != null &&
        widget.customThumbnailPath!.startsWith('http')) {
      final String effectiveUrl = BunnyCDNService.signUrl(widget.customThumbnailPath!);
      final bool isStorageUrl = effectiveUrl.contains('storage.bunnycdn.com');
      return CachedNetworkImage(
        imageUrl: effectiveUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        httpHeaders: {
          if (!isStorageUrl) 'Referer': ConfigService.allowedReferer,
          if (isStorageUrl) 'AccessKey': BunnyCDNService.apiKey,
        },
        errorWidget: (_, __, ___) => _buildFallbackIcon(),
        placeholder: (_, __) => _buildShimmer(),
      );
    }

    if (widget.videoPath.startsWith('http')) {
      // 🎥 Guess Bunny Stream Thumbnail
      String? guessedThumb;
      final String cdnHost = ConfigService().bunnyStreamCdnHost;
      final String videoPath = widget.videoPath;
      
      if (videoPath.contains(cdnHost)) {
        try {
          final uri = Uri.parse(videoPath);
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segments.isNotEmpty) {
            final videoId = segments.firstWhere(
              (s) => s.length > 20, 
              orElse: () => segments[0]
            );
            guessedThumb = 'https://$cdnHost/$videoId/thumbnail.jpg';
          }
        } catch (_) {}
      } else if (videoPath.contains('iframe.mediadelivery.net')) {
        try {
          final uri = Uri.parse(videoPath);
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segments.isNotEmpty) {
            String videoId = segments.last;
            if (videoId.contains('?')) {
              videoId = videoId.split('?').first;
            }
            guessedThumb = 'https://$cdnHost/$videoId/thumbnail.jpg';
          }
        } catch (_) {}
      } else if (videoPath.contains('.b-cdn.net') || videoPath.contains('bunnycdn.com')) {
          // If it's a direct mp4 on bunny storage, guess the thumb
          guessedThumb = videoPath.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv|m3u8)$'), '.jpg');
      }

      if (guessedThumb != null) {
        final String effectiveThumb = BunnyCDNService.signUrl(guessedThumb);
        final bool isStorageThumb = effectiveThumb.contains('storage.bunnycdn.com');
        return CachedNetworkImage(
          imageUrl: effectiveThumb,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          httpHeaders: {
            if (!isStorageThumb) 'Referer': ConfigService.allowedReferer,
            if (isStorageThumb) 'AccessKey': BunnyCDNService.apiKey,
          },
          errorWidget: (_, __, ___) => _buildFallbackIcon(),
          placeholder: (_, __) => _buildShimmer(),
        );
      }

      return _buildFallbackIcon();
    }

    if (_hasError || _thumbnailData == null) {
      return _buildFallbackIcon();
    }

    return Image.memory(
      _thumbnailData!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      cacheWidth:
          (widget.width != null &&
              widget.width! > 0 &&
              widget.width! != double.infinity)
          ? widget.width!.toInt()
          : null,
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black12,
      child: const Icon(Icons.play_circle_outline, color: Colors.white24),
    );
  }

  Widget _buildShimmer() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black12,
    );
  }
}
