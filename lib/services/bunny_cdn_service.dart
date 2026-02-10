import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'logger_service.dart';
import 'config_service.dart';

class BunnyCDNService {
  // Bunny.net Storage Zone Configuration
  static const String storageZoneName = 'lme-media-storage';
  static const String hostname =
      'sg.storage.bunnycdn.com'; // Verified Region: Singapore

  static String get apiKey => ConfigService().bunnyStorageKey;

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

        final apiUrl = 'https://$hostname/$storageZoneName/$remotePath';
        final stream = file.openRead();

        LoggerService.info(
          "Starting Upload: $fileName -> $remotePath (Attempt $attempts) | Size: ${(fileSize / 1024).toStringAsFixed(2)} KB",
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
            }
            onProgress?.call(sent, total);
          },
          cancelToken: cancelToken,
        );

        LoggerService.info(
          "PUT Response: ${response.statusCode}",
          tag: 'BUNNY_CDN',
        );

        if (response.statusCode != 201 && response.statusCode != 200) {
          throw Exception(
            'Upload failed (${response.statusCode}): ${response.data}',
          );
        }

        final publicUrl = '$cdnUrl/$remotePath';
        LoggerService.success("Upload Complete: $publicUrl", tag: 'BUNNY_CDN');
        return Uri.encodeFull(publicUrl);
      } catch (e) {
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
      final apiUrl = 'https://$hostname/$storageZoneName/$remotePath';
      final response = await _dio.delete(
        apiUrl,
        options: Options(headers: {'AccessKey': apiKey}),
      );
      if (response.statusCode == 200) {
        LoggerService.success("Deleted file: $remotePath", tag: 'BUNNY_CDN');
        return true;
      }
      return false;
    } catch (e) {
      LoggerService.error('Bunny CDN Storage delete error: $e', tag: 'CDN');
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
      return response.statusCode == 200;
    } catch (e) {
      LoggerService.error('Bunny Stream delete error: $e', tag: 'CDN');
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

    // Only transform if it's our specific Storage Zone CDN
    // This prevents breaking Bunny Stream thumbnails (which also use b-cdn.net but different host)
    if (publicUrl.startsWith(cdnUrl)) {
      try {
        String pathPart = publicUrl.split(cdnUrl).last;
        if (pathPart.startsWith('/')) pathPart = pathPart.substring(1);

        final decoded = Uri.decodeFull(pathPart);
        final segments = decoded.split('/');
        final encodedSegments = segments
            .map((s) => Uri.encodeComponent(s))
            .toList();
        final targetPath = encodedSegments.join('/');

        return 'https://sg.storage.bunnycdn.com/lme-media-storage/$targetPath';
      } catch (e) {
        return publicUrl.replaceFirst(
          cdnUrl,
          'https://sg.storage.bunnycdn.com/lme-media-storage',
        );
      }
    }

    return publicUrl;
  }
}
