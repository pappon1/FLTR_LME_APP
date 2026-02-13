import '../services/config_service.dart';

class ContentNormalizer {
  static bool isLocalPath(String? p) {
    final s = p?.toString() ?? '';
    return s.isNotEmpty && s.startsWith('/');
  }

  static String normalizePath(String? rawPath) {
    if (rawPath == null) return '';
    final String cdnHost = ConfigService().bunnyStreamCdnHost;
    if (!rawPath.contains(cdnHost)) return rawPath;
    try {
      final uri = Uri.parse(rawPath);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      String? videoId;
      if (segments.isNotEmpty) {
        videoId = segments.firstWhere(
          (s) => s.length > 20 && !s.contains('.'),
          orElse: () => segments[0],
        );
      }
      if (videoId != null &&
          videoId != cdnHost &&
          !videoId.startsWith('http') &&
          videoId.length > 5) {
        if (videoId.contains('?')) {
          videoId = videoId.split('?').first;
        }
        return 'https://$cdnHost/$videoId/playlist.m3u8';
      }
    } catch (_) {}
    return rawPath;
  }

  static Map<String, dynamic> normalizeItem(Map<String, dynamic> item) {
    final cdnHost = ConfigService().bunnyStreamCdnHost;
    final converted = Map<String, dynamic>.from(item);
    final String? rawPath =
        (converted['path'] ?? converted['videoUrl'] ?? converted['url'])
            ?.toString();
    if (rawPath != null && rawPath.contains(cdnHost)) {
      try {
        final uri = Uri.parse(rawPath);
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        String? videoId;
        if (segments.isNotEmpty) {
          videoId = segments.firstWhere(
            (s) => s.length > 20 && !s.contains('.'),
            orElse: () => segments[0],
          );
        }
        if (videoId != null &&
            videoId != cdnHost &&
            !videoId.startsWith('http') &&
            videoId.length > 5) {
          if (videoId.contains('?')) {
            videoId = videoId.split('?').first;
          }
          converted['path'] = 'https://$cdnHost/$videoId/playlist.m3u8';
          if (converted['thumbnail'] == null ||
              converted['thumbnail'].toString().isEmpty) {
            converted['thumbnail'] = 'https://$cdnHost/$videoId/thumbnail.jpg';
          }
        } else {
          converted['path'] = rawPath;
        }
      } catch (_) {
        converted['path'] = rawPath;
      }
    } else if (rawPath != null) {
      converted['path'] = rawPath;
    }
    return converted;
  }

  static List<Map<String, dynamic>> normalizeList(
    List<Map<String, dynamic>> rawContents,
  ) {
    return rawContents.map(normalizeItem).toList();
  }
}
