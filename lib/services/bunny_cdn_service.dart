import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'logger_service.dart';
import 'config_service.dart';

class BunnyCDNService {
  // Bunny.net Storage Zone Configuration
  static const String storageZoneName = 'lme-media-storage';
  static const String hostname =
      'sg.storage.bunnycdn.com'; // Use Singapore storage endpoint (Verified fix for 401)

  static String get apiKey {
    // ⚡ USER VERIFIED KEY: Priority override for reliability
    // "bunny pdf image read write password - 47d150e7-c234-4267-85a4018657d5-afa6-4d5c"
    const verifiedKey = '47d150e7-c234-4267-85a4018657d5-afa6-4d5c';
    
    // Check if ConfigService has a different key, but prefer verified one if it's there
    try {
      final configKey = ConfigService().bunnyStorageKey;
      if (configKey.isNotEmpty && configKey != verifiedKey) {
        // Log if they differ for debugging
        debugPrint('ℹ️ [BUNNY] Using key from ConfigService: ${configKey.substring(0, 5)}...');
        return configKey;
      }
    } catch (_) {}

    return verifiedKey;
  }

  static const String cdnUrl = 'https://lme-media-storage.b-cdn.net';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 60),
      sendTimeout: const Duration(minutes: 60),
    ),
  );

  /// Upload file to Bunny.net CDN
  Future<String> uploadFile({
    required String filePath,
    required String remotePath,
    Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    int attempts = 0;
    const int maxRetries = 3;

    while (attempts < maxRetries) {
      try {
        attempts++;
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File not found: $filePath');
        }

        final fileSize = await file.length();
        final fileName = path.basename(filePath);

        if (apiKey.isEmpty) {
          LoggerService.warning(
            "API Key missing. Attempting lazy initialization...",
            tag: 'BUNNY_CDN',
          );
          await ConfigService().initialize();
        }

        if (apiKey.isEmpty) {
          throw Exception(
            'CDN API Key is missing. Please restart the app or check internet.',
          );
        }

        // Ensure remotePath is clean and properly formatted
        String normalizedRemotePath = remotePath.trim();
        if (normalizedRemotePath.startsWith('/')) {
          normalizedRemotePath = normalizedRemotePath.substring(1);
        }

        final apiUrl = 'https://$hostname/$storageZoneName/$normalizedRemotePath';
        final stream = file.openRead();

        LoggerService.info(
          "Starting Upload: $fileName -> $normalizedRemotePath (Attempt $attempts) | Size: ${(fileSize / 1024).toStringAsFixed(2)} KB | API: $apiUrl",
          tag: 'BUNNY_CDN',
        );

        final response = await _dio.put(
          apiUrl,
          data: stream,
          options: Options(
            validateStatus: (status) => status! < 500,
            headers: {
              'AccessKey': apiKey,
              'Content-Type': _getContentType(fileName),
              'Content-Length': fileSize,
            },
          ),
          onSendProgress: (sent, total) {
            if (total > 0) {
              final percentage = (sent / total * 100).floor();
              // Log every 20% to avoid spam
              if (percentage % 20 == 0 && percentage > 0) {
                LoggerService.info(
                  "Upload Progress ($fileName): $percentage%",
                  tag: 'BUNNY_CDN',
                );
              }
              if (onProgress != null) onProgress(sent, total);
            }
          },
          cancelToken: cancelToken,
        );

        LoggerService.info(
          "HTTP Response (${response.statusCode}) from Bunny.net",
          tag: 'BUNNY_CDN',
        );

        if (response.statusCode != 201 && response.statusCode != 200) {
          throw Exception(
            'Upload failed (${response.statusCode}): ${response.data}',
          );
        }

        // Always build public URL using the verified static cdnUrl
        final publicUrl = '$cdnUrl/$normalizedRemotePath';
        LoggerService.success("Upload Complete: $publicUrl", tag: 'BUNNY_CDN');
        
        // Return encoded URL but ensure it's the full public CDN URL
        return Uri.encodeFull(publicUrl);
      } catch (e) {
        LoggerService.error("Upload Attempt $attempts Failed: $e", tag: 'BUNNY_CDN');
        if (e is DioException && e.type == DioExceptionType.cancel) {
          rethrow;
        }
        if (attempts >= maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
    throw Exception('Upload failed after $maxRetries attempts');
  }

  /// Delete file from Bunny.net CDN
  Future<bool> deleteFile(String remotePath) async {
    try {
      // Clean the remote path
      String cleanPath = remotePath;

      // If it's a full URL, extract just the path part
      if (cleanPath.contains('://')) {
        final uri = Uri.parse(cleanPath);
        cleanPath = uri.path;
        if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
      }

      final apiUrl = 'https://$hostname/$storageZoneName/$cleanPath';

      final response = await _dio.delete(
        apiUrl,
        options: Options(headers: {'AccessKey': apiKey}),
      );

      if (response.statusCode == 200) {
        LoggerService.success("✅ Deleted file: $cleanPath", tag: 'BUNNY_CDN');
        return true;
      }
      return false;
    } catch (e) {
      LoggerService.error('❌ Bunny CDN Storage delete error', tag: 'BUNNY_CDN');
      return false;
    }
  }

  /// Delete video from Bunny.net Stream
  Future<bool> deleteVideo({
    required String libraryId,
    required String videoId,
    required String apiKey,
  }) async {
    try {
      final apiUrl =
          'https://video.bunnycdn.com/library/$libraryId/videos/$videoId';

      final response = await _dio.delete(
        apiUrl,
        options: Options(
          headers: {'AccessKey': apiKey, 'accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        LoggerService.success("✅ Deleted video: $videoId", tag: 'BUNNY_STREAM');
        return true;
      }
      return false;
    } catch (e) {
      LoggerService.error('❌ Bunny Stream delete error', tag: 'BUNNY_STREAM');
      return false;
    }
  }

  /// List all videos in a Bunny Stream library (Handles Pagination)
  Future<List<String>> listVideos({
    required String libraryId,
    required String apiKey,
  }) async {
    List<String> allVideoIds = [];
    int page = 1;
    bool hasMore = true;

    try {
      while (hasMore) {
        final apiUrl =
            'https://video.bunnycdn.com/library/$libraryId/videos?page=$page&itemsPerPage=100';
        final response = await _dio.get(
          apiUrl,
          options: Options(
            headers: {'AccessKey': apiKey, 'accept': 'application/json'},
          ),
        );

        if (response.statusCode == 200) {
          final List<dynamic> items = response.data['items'] ?? [];
          if (items.isEmpty) {
            hasMore = false;
          } else {
            allVideoIds.addAll(items.map((e) => e['guid'].toString()));
            page++;
            // If we got fewer than 100 items, we've reached the end
            if (items.length < 100) hasMore = false;
          }
        } else {
          hasMore = false;
        }
      }
      return allVideoIds;
    } catch (e) {
      return allVideoIds;
    }
  }

  /// Find a collection by name in Bunny Stream
  Future<String?> findCollectionByName({
    required String libraryId,
    required String apiKey,
    required String name,
  }) async {
    try {
      final apiUrl =
          'https://video.bunnycdn.com/library/$libraryId/collections';
      final response = await _dio.get(
        apiUrl,
        options: Options(
          headers: {'AccessKey': apiKey, 'accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> collections = response.data['items'] ?? [];
        for (var col in collections) {
          if (col['name'] == name) {
            return col['guid'].toString();
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create a collection (Folder) in Bunny Stream
  Future<String?> createCollection({
    required String libraryId,
    required String apiKey,
    required String name,
  }) async {
    try {
      final apiUrl =
          'https://video.bunnycdn.com/library/$libraryId/collections';
      final response = await _dio.post(
        apiUrl,
        data: {'name': name},
        options: Options(
          headers: {
            'AccessKey': apiKey,
            'accept': 'application/json',
            'content-type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final collectionId = response.data['guid'].toString();
        LoggerService.success(
          "✅ Created collection: $name ($collectionId)",
          tag: 'BUNNY_STREAM',
        );
        return collectionId;
      }
      return null;
    } catch (e) {
      LoggerService.error(
        '❌ Bunny Stream create collection error: $e',
        tag: 'BUNNY_STREAM',
      );
      return null;
    }
  }

  /// Delete a collection from Bunny Stream
  Future<bool> deleteCollection({
    required String libraryId,
    required String apiKey,
    required String collectionId,
  }) async {
    try {
      final apiUrl =
          'https://video.bunnycdn.com/library/$libraryId/collections/$collectionId';
      final response = await _dio.delete(
        apiUrl,
        options: Options(
          headers: {'AccessKey': apiKey, 'accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        LoggerService.success(
          "✅ Deleted collection: $collectionId",
          tag: 'BUNNY_STREAM',
        );
        return true;
      }
      return false;
    } catch (e) {
      LoggerService.error(
        '❌ Bunny Stream delete collection error: $e',
        tag: 'BUNNY_STREAM',
      );
      return false;
    }
  }

  /// List videos in a specific collection (Handles Pagination)
  Future<List<String>> listVideosInCollection({
    required String libraryId,
    required String apiKey,
    required String collectionId,
  }) async {
    List<String> allVideoIds = [];
    int page = 1;
    bool hasMore = true;

    try {
      while (hasMore) {
        final apiUrl =
            'https://video.bunnycdn.com/library/$libraryId/videos?collection=$collectionId&page=$page&itemsPerPage=100';
        final response = await _dio.get(
          apiUrl,
          options: Options(
            headers: {'AccessKey': apiKey, 'accept': 'application/json'},
          ),
        );

        if (response.statusCode == 200) {
          final List<dynamic> items = response.data['items'] ?? [];
          if (items.isEmpty) {
            hasMore = false;
          } else {
            allVideoIds.addAll(items.map((e) => e['guid'].toString()));
            page++;
            if (items.length < 100) hasMore = false;
          }
        } else {
          hasMore = false;
        }
      }
      return allVideoIds;
    } catch (e) {
      return allVideoIds;
    }
  }

  /// Delete a collection and all videos inside it
  Future<void> deleteCollectionWithVideos({
    required String libraryId,
    required String apiKey,
    required String collectionId,
  }) async {
    try {
      // 1. List all videos in the collection
      final videoIds = await listVideosInCollection(
        libraryId: libraryId,
        apiKey: apiKey,
        collectionId: collectionId,
      );

      // 2. Delete each video
      for (final videoId in videoIds) {
        await deleteVideo(
          libraryId: libraryId,
          videoId: videoId,
          apiKey: apiKey,
        );
      }

      // 3. Delete the collection itself
      await deleteCollection(
        libraryId: libraryId,
        apiKey: apiKey,
        collectionId: collectionId,
      );
    } catch (e) {
      LoggerService.error(
        '❌ Error deleting collection with videos: $e',
        tag: 'BUNNY_STREAM',
      );
    }
  }

  /// Delete ALL videos from a specific library (USE WITH CAUTION)
  Future<int> deleteAllVideosFromLibrary({
    required String libraryId,
    required String apiKey,
  }) async {
    int count = 0;
    try {
      // 1. Delete all individual videos
      final videoIds = await listVideos(libraryId: libraryId, apiKey: apiKey);
      for (final videoId in videoIds) {
        final success = await deleteVideo(
          libraryId: libraryId,
          videoId: videoId,
          apiKey: apiKey,
        );
        if (success) count++;
      }

      // 2. Delete all collections (Folders)
      final apiUrl =
          'https://video.bunnycdn.com/library/$libraryId/collections';
      final response = await _dio.get(
        apiUrl,
        options: Options(
          headers: {'AccessKey': apiKey, 'accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> collections = response.data['items'] ?? [];
        for (var col in collections) {
          await deleteCollection(
            libraryId: libraryId,
            apiKey: apiKey,
            collectionId: col['guid'].toString(),
          );
        }
      }
    } catch (e) {
      // Silent error for global cleanup
    }
    return count;
  }

  /// Delete entire folder (directory) from Bunny.net Storage
  /// This will delete the folder and ALL its contents recursively
  Future<bool> deleteFolder(String folderPath) async {
    try {
      // Clean the folder path
      String cleanPath = folderPath;

      // Remove leading slash if present
      if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);

      // Ensure trailing slash for folder
      if (!cleanPath.endsWith('/')) cleanPath = '$cleanPath/';

      final apiUrl = 'https://$hostname/$storageZoneName/$cleanPath';

      final response = await _dio.delete(
        apiUrl,
        options: Options(headers: {'AccessKey': apiKey}),
      );

      if (response.statusCode == 200) {
        LoggerService.success("✅ Deleted folder: $cleanPath", tag: 'BUNNY_CDN');
        return true;
      }
      return false;
    } catch (e) {
      LoggerService.error('❌ Bunny CDN folder delete error', tag: 'BUNNY_CDN');
      return false;
    }
  }

  String _getContentType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.mp4':
        return 'video/mp4';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  /// Upload video file
  Future<String> uploadVideo({
    required String filePath,
    required String courseId,
    required String videoId,
    Function(int sent, int total)? onProgress,
  }) async {
    final remotePath = 'videos/$courseId/$videoId${path.extension(filePath)}';
    return uploadFile(
      filePath: filePath,
      remotePath: remotePath,
      onProgress: onProgress,
    );
  }

  /// Upload image file
  Future<String> uploadImage({
    required String filePath,
    required String folder,
    Function(int sent, int total)? onProgress,
  }) async {
    final extension = path.extension(filePath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
    final remotePath = 'images/$folder/$fileName';
    return uploadFile(
      filePath: filePath,
      remotePath: remotePath,
      onProgress: onProgress,
    );
  }

  /// Upload PDF file
  Future<String> uploadPDF({
    required String filePath,
    required String courseId,
    Function(int sent, int total)? onProgress,
  }) async {
    final fileName = path.basename(filePath);
    final remotePath = 'pdfs/$courseId/$fileName';
    return uploadFile(
      filePath: filePath,
      remotePath: remotePath,
      onProgress: onProgress,
    );
  }

  /// Get the Authenticated URL for Admin access (Direct Storage)
  String getAuthenticatedUrl(String publicUrl) {
    return signUrl(publicUrl);
  }

  static String signUrl(String publicUrl) {
    if (publicUrl.isEmpty) return publicUrl;

    debugPrint('🛡️ [SIGN_URL] Processing: $publicUrl');

    // Handle multiple zones
    final zones = ['lme-media-storage', 'official-mobile-engineer'];
    String? matchedZone;
    for (final zone in zones) {
      if (publicUrl.toLowerCase().contains('$zone.b-cdn.net')) {
        matchedZone = zone;
        break;
      }
    }

    if (matchedZone != null) {
      try {
        String pathPart = publicUrl.split('.b-cdn.net').last;
        if (pathPart.startsWith('/')) pathPart = pathPart.substring(1);

        // Remove query parameters if any
        if (pathPart.contains('?')) {
          pathPart = pathPart.split('?').first;
        }

        final decoded = Uri.decodeFull(pathPart);
        final segments = decoded.split('/');
        final encodedSegments = segments
            .map((s) => Uri.encodeComponent(s))
            .toList();
        final targetPath = encodedSegments.join('/');

        // ⚡ REGIONAL FIX: Use sg.storage.bunnycdn.com as verified by auth_test
        final signed =
            'https://sg.storage.bunnycdn.com/$matchedZone/$targetPath';
        debugPrint('🛡️ [SIGN_URL] Result: $signed');
        return signed;
      } catch (e) {
        debugPrint('🛡️ [SIGN_URL] Error: $e');
        return publicUrl;
      }
    }

    return publicUrl;
  }
}
