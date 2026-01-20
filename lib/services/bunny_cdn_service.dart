import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

class BunnyCDNService {
  // Bunny.net Storage Zone Configuration
  // Bunny.net Storage Zone Configuration
  static const String storageZoneName = 'lme-media-storage';
  static const String hostname = 'sg.storage.bunnycdn.com'; // Verified Region: Singapore
  static const String apiKey = 'eae59342-6952-4d56-bb2fb8745da1-adf7-402d'; // Verified API Key
  static const String cdnUrl = 'https://lme-media-storage.b-cdn.net';
  
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 60), // Long timeout for large files
    sendTimeout: const Duration(minutes: 60),
  ));

  /// Upload file to Bunny.net CDN with Stream (Memory Efficient) and Retry Logic
  Future<String> uploadFile({
    required String filePath,
    required String remotePath,
    Function(int sent, int total)? onProgress,
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
        
        // Construct API endpoint
        final apiUrl = 'https://$hostname/$storageZoneName/$remotePath';
        
        // Use openRead for streaming (Low RAM usage)
        final stream = file.openRead();

        final response = await _dio.put(
          apiUrl,
          data: stream, 
          options: Options(
            headers: {
              'AccessKey': apiKey,
              'Content-Type': _getContentType(fileName),
              'Content-Length': fileSize, // Critical for Stream upload
            },
          ),
          onSendProgress: onProgress,
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          final publicUrl = '$cdnUrl/$remotePath';
          return Uri.encodeFull(publicUrl);
        } else {
          throw Exception('Upload failed with status: ${response.statusCode}');
        }
      } catch (e) {
        if (attempts >= maxRetries) {
           rethrow;
        }
        // Wait before retrying (exponential backoff)
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
      // print('❌ Bunny CDN delete error: $e');
      return false;
    }
  }

  /// Get content type based on file extension
  String _getContentType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    
    switch (extension) {
      case '.mp4':
      case '.mov':
      case '.avi':
      case '.mkv':
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
      case '.rar':
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
    // If it's already a public CDN URL, convert to Storage URL
    if (publicUrl.startsWith(cdnUrl)) {
      return publicUrl.replaceFirst(cdnUrl, 'https://$hostname/$storageZoneName');
    }
    return publicUrl;
  }
}
