import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:shimmer/shimmer.dart';
import '../models/course_model.dart';
import '../services/bunny_cdn_service.dart';
import '../services/config_service.dart';

/// 🖼️ Optimized Thumbnail Widget for Courses
/// Handles local files, Bunny Stream fallback, and guesses thumbnails from content.
class CourseThumbnailWidget extends StatelessWidget {
  final CourseModel course;
  final bool isDark;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  const CourseThumbnailWidget({
    super.key,
    required this.course,
    required this.isDark,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0.0,
  });

  String get thumbnailUrl => course.thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    String effectiveUrl = thumbnailUrl.trim();
    debugPrint('🚀 CourseThumbnailWidget BUILDING for ${course.title} | URL: $effectiveUrl');

    // 1. If the course thumbnail is missing, try fallback from contents
    if (effectiveUrl.isEmpty || effectiveUrl == 'null' || effectiveUrl == 'undefined') {
      final String? streamThumb = _findFallbackThumbnail(course.contents);
      if (streamThumb != null && streamThumb.isNotEmpty) {
        effectiveUrl = streamThumb;
      }
    }

    // 2. Convert video URLs to thumbnail format (if a video link was saved as the thumbnail)
    effectiveUrl = _ensureThumbnailFormat(effectiveUrl);

    // 3. Final check for empty
    if (effectiveUrl.isEmpty || effectiveUrl == 'null' || effectiveUrl == 'undefined') {
      return _buildPlaceholder();
    }

    final bool isLocal = effectiveUrl.startsWith('/') || effectiveUrl.contains(':\\');

    if (isLocal) {
      return Image.file(
        File(effectiveUrl),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    // 🕵️ CRITICAL AUTH: Use signedUrl to ensure we go through the Storage API (AccessKey-based).
    // This is necessary if the direct CDN URL is private or restricted.
    final String displayUrl = BunnyCDNService.signUrl(effectiveUrl);
    final bool isStorageUrl = displayUrl.contains('storage.bunnycdn.com');

    return CachedNetworkImage(
      imageUrl: displayUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 300),
      httpHeaders: {
        // ⚡ CRITICAL FIX: Bunny Storage rejects requests if Referer is present
        if (!isStorageUrl) 'Referer': ConfigService.allowedReferer,
        if (isStorageUrl) 'AccessKey': BunnyCDNService.apiKey,
      },
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) {
        if (kDebugMode) {
          debugPrint('❌ CourseThumbnail Error: Failed to load $displayUrl');
        }
        return _buildErrorWidget();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey,
        size: (width != null && width! < 100) ? 24 : 48,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image,
        color: Colors.grey,
        size: (width != null && width! < 100) ? 24 : 48,
      ),
    );
  }

  String _ensureThumbnailFormat(String url) {
    if (url.isEmpty || url == 'null' || url == 'undefined') return url;

    // If it's already an image, return it
    final lower = url.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp')) {
      return url;
    }

    // If it's a Bunny Stream URL (HLS playlist or direct ID), convert to thumbnail
    final String cdnHost = ConfigService().bunnyStreamCdnHost;
    if (url.contains(cdnHost) || url.contains('vz-')) {
       final videoId = _extractVideoId(url);
       if (videoId != null) {
         return 'https://$cdnHost/$videoId/thumbnail.jpg';
       }
    }

    return url;
  }

  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      
      if (segments.isNotEmpty) {
        // Try to find a long hex/uuid segment
        for (var s in segments) {
           if (s.length > 20 && !s.contains('.')) return s;
        }
        return segments[0];
      }
    } catch (_) {}
    return null;
  }

  String _findFallbackThumbnail(List<dynamic> contents) {
    for (var item in contents) {
      Map? map;
      if (item is Map) {
        map = item;
      } else if (item.runtimeType.toString() == 'CourseContent') {
         // Fallback for custom objects
         try {
           map = (item as dynamic).toMap();
         } catch (_) {}
      }

      if (map != null) {
        final thumb = map['thumbnail']?.toString() ?? '';
        final fixedThumb = _ensureThumbnailFormat(thumb);
        
        if (fixedThumb.isNotEmpty && fixedThumb != 'null' && fixedThumb != 'undefined' && !fixedThumb.startsWith('/')) {
          if (fixedThumb.contains('b-cdn.net') || fixedThumb.contains(ConfigService().bunnyStreamCdnHost)) {
             return fixedThumb;
          }
        }

        if (map['type'] == 'video' || map['type'] == 'folder') {
           final videoUrl = (map['path'] ?? map['videoUrl'] ?? map['url'])?.toString() ?? '';
           final guessed = _ensureThumbnailFormat(videoUrl);
           if (guessed.contains('/thumbnail.jpg')) return guessed;
        }

        if (map['contents'] != null) {
          final sub = _findFallbackThumbnail(map['contents'] as List);
          if (sub.isNotEmpty) return sub;
        }
      }
    }
    return '';
  }
}
