import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

class BunnyCDNService {
  // Bunny.net Storage Zone Configuration
  // Bunny.net Storage Zone Configuration
  static const String storageZoneName = 'lme-media-storage';
  static const String hostname = 'sg.storage.bunnycdn.com';
  static const String apiKey = 'eae59342-6952-4d56-bb2fb8745da1-adf7-402d'; // Renamed to apiKey for clarity
  static const String cdnUrl = 'https://lme-media-storage.b-cdn.net';
  
  final Dio _dio = Dio();

  /// Upload file to Bunny.net CDN
  Future<String> uploadFile({
    required String filePath,
    required String remotePath,
    Function(int sent, int total)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      final fileBytes = await file.readAsBytes();
      final fileName = path.basename(filePath);
      
      // Construct API endpoint
      final apiUrl = 'https://$hostname/$storageZoneName/$remotePath';
      
      print('🚀 Uploading to Bunny CDN: $apiUrl (Size: ${fileBytes.length} bytes)');
      
      final response = await _dio.put(
        apiUrl,
        data: Stream.fromIterable([fileBytes]), 
        options: Options(
          headers: {
            'AccessKey': apiKey,
            'Content-Type': _getContentType(fileName),
            'Content-Length': fileBytes.length,
          },
        ),
        onSendProgress: onProgress,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final publicUrl = '$cdnUrl/$remotePath';
        print('✅ Upload successful: $publicUrl');
        return Uri.encodeFull(publicUrl);
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Bunny CDN upload error: $e');
      rethrow;
    }
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
      print('❌ Bunny CDN delete error: $e');
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
        return 'video/mp4';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
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
    // If it's already a public CDN URL, convert to Storage URL
    if (publicUrl.startsWith(cdnUrl)) {
      return publicUrl.replaceFirst(cdnUrl, 'https://$hostname/$storageZoneName');
    }
    return publicUrl;
  }
}
