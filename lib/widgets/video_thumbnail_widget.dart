import 'dart:typed_data';
import 'dart:io' as java_io;
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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
    if (oldWidget.videoPath != widget.videoPath) {
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
    
    // Check if we already have it in memory (using path as key)
    if (VideoThumbnailWidget._memoryCache.containsKey(widget.customThumbnailPath!)) {
        setState(() {
          _thumbnailData = VideoThumbnailWidget._memoryCache[widget.customThumbnailPath!];
          _isLoading = false;
          _hasError = false;
        });
        return;
    }

    try {
      final file = java_io.File(widget.customThumbnailPath!); // Use alias if needed or just File
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
        quality: 35,   // Reduced quality for better performance
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
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
          ),
        ),
      );
    }

    if (_hasError || _thumbnailData == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.transparent,
      );
    }

    return Image.memory(
      _thumbnailData!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      cacheWidth: (widget.width != null && widget.width! > 0 && widget.width! != double.infinity) 
          ? widget.width!.toInt() 
          : null, 
    );
  }
}
