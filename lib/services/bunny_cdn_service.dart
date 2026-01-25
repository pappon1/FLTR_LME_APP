import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

class BunnyCDNService {
  // Bunny.net Storage Zone Configuration
  static const String storageZoneName = 'lme-media-storage';
  static const String hostname = 'sg.storage.bunnycdn.com'; // Verified Region: Singapore
  static const String apiKey = 'eae59342-6952-4d56-bb2fb8745da1-adf7-402d'; // Admin Storage Key
  static const String cdnUrl = 'https://lme-media-storage.b-cdn.net';
  
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 60),
    sendTimeout: const Duration(minutes: 60),
  ));

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
          onSendProgress: onProgress,
          cancelToken: cancelToken,
        );

        if (response.statusCode != 201 && response.statusCode != 200) {
           throw Exception('Upload failed (${response.statusCode}): ${response.data}');
        }

        final publicUrl = '$cdnUrl/$remotePath';
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
        options: Options(
          headers: {
            'AccessKey': apiKey,
          },
        ),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('❌ Bunny CDN Storage delete error: $e');
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
      final apiUrl = 'https://video.bunnycdn.com/library/$libraryId/videos/$videoId';
      final response = await _dio.delete(
        apiUrl,
        options: Options(
          headers: {
            'AccessKey': apiKey,
            'accept': 'application/json',
          },
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Bunny Stream delete error: $e');
      return false;
    }
  }

  String _getContentType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    switch (extension) {
      case '.mp4': return 'video/mp4';
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.png': return 'image/png';
      case '.webp': return 'image/webp';
      case '.pdf': return 'application/pdf';
      case '.zip': return 'application/zip';
      default: return 'application/octet-stream';
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
        final encodedSegments = segments.map((s) => Uri.encodeComponent(s)).toList();
        final targetPath = encodedSegments.join('/');
        
        return 'https://sg.storage.bunnycdn.com/lme-media-storage/$targetPath';
      } catch (e) {
        return publicUrl.replaceFirst(cdnUrl, 'https://sg.storage.bunnycdn.com/lme-media-storage');
      }
    }
    
    return publicUrl; 
  }
}
