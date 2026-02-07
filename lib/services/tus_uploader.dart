import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

class TusUploader {
  final Dio _dio = Dio();
  final String apiKey;
  final String libraryId;
  final String videoId;

  // Bunny Stream TUS Endpoint
  static const String _baseUrl = 'https://video.bunnycdn.com/tusupload';

  TusUploader({
    required this.apiKey,
    required this.libraryId,
    required this.videoId,
  });

  /// Uploads a file using TUS protocol with Resume capability
  Future<String> upload(
    File file, {
    Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
    int? chunkSize, // Optional chunk size
  }) async {
    final int fileSize = await file.length();
    final String filename = path.basename(file.path);
    // Include videoId and libraryId in fingerprint to ensure we always get the RIGHT session
    final String fingerprint = "$filename-$fileSize-$libraryId-$videoId";

    // 1. Check for existing upload URL (Resume)
    LoggerService.info("Checking session for fingerprint: $fingerprint", tag: 'TUS');
    final session = await _getSession(fingerprint);
    String? uploadUrl = session?['url'];
    String? currentVideoId = session?['videoId'];
    int offset = 0;

    if (uploadUrl != null) {
      // Fix Relative Path if saved in old format
      if (uploadUrl.startsWith('/')) {
        uploadUrl = "https://video.bunnycdn.com$uploadUrl";
      }

      try {
        LoggerService.info("Verifying session: $uploadUrl", tag: 'TUS');
        final headResponse = await _dio.head(
          uploadUrl,
          options: Options(
            headers: {
              'Tus-Resumable': '1.0.0',
              'AccessKey': apiKey,
              'LibraryId': libraryId,
            },
            validateStatus: (status) => status == 200 || status == 204,
          ),
        );

        final serverOffset = headResponse.headers.value('Upload-Offset');
        if (serverOffset != null) {
          offset = int.parse(serverOffset);
          LoggerService.success(
              "Resuming from Server Offset: $offset bytes", tag: 'TUS');
          if (onProgress != null) onProgress(offset, fileSize);
        } else {
          LoggerService.warning(
              "No Upload-Offset found in HEAD response.", tag: 'TUS');
          uploadUrl = null; // Force fresh POST if session is invalid
        }
      } catch (e) {
        if (e is DioException &&
            (e.response?.statusCode == 404 || e.response?.statusCode == 410)) {
          LoggerService.warning(
              "TUS Session Expired (404). Starting fresh.", tag: 'TUS');
          uploadUrl = null;
          await _clearSession(fingerprint);
        } else {
          LoggerService.error(
              "Network error during Handshake: $e. Cannot resume safely.",
              tag: 'TUS');
          rethrow; // Don't fall back to 0% if it's just a network error!
        }
      }
    }

    // 2. Create new Upload (POST) ONLY if we don't have a valid resume URL
    if (uploadUrl == null) {
      LoggerService.info(
          "No valid session found for $filename. Creating new POST.",
          tag: 'TUS');
      try {
        final metadata = {
          'libraryid': base64Encode(utf8.encode(libraryId)),
          'title': base64EnFilename(file.path),
          'filetype': base64EnFiletype(file.path),
        };

        if (videoId.isNotEmpty) {
          metadata['video_id'] = base64Encode(utf8.encode(videoId));
        }

        final metadataStr =
            metadata.entries.map((e) => "${e.key} ${e.value}").join(",");
        final headers = {
          'Tus-Resumable': '1.0.0',
          'Upload-Length': fileSize.toString(),
          'Upload-Metadata': metadataStr,
          'AccessKey': apiKey,
          'LibraryId': libraryId,
        };

        final response = await _dio.post(
          _baseUrl,
          options: Options(
            validateStatus: (status) => status == 200 || status == 201,
            headers: headers,
          ),
        );

        uploadUrl = response.headers.value('Location');
        currentVideoId = response.headers.value('Stream-Media-Id');

        if (uploadUrl == null) {
          throw Exception("Server did not return a Location header.");
        }
        if (uploadUrl.startsWith('/')) {
          uploadUrl = "https://video.bunnycdn.com$uploadUrl";
        }
        if (currentVideoId == null || currentVideoId.isEmpty) {
          currentVideoId = uploadUrl.split('/').last;
        }

        await _saveSession(fingerprint, uploadUrl, currentVideoId);
        LoggerService.success("New Session Created: $uploadUrl", tag: 'TUS');
      } on DioException catch (e) {
        final errorData = e.response?.data;
        LoggerService.error("Creation Error Status: ${e.response?.statusCode}",
            tag: 'TUS');
        LoggerService.error("Creation Error Body: $errorData", tag: 'TUS');

        String errorMsg = "Upload Creation Failed (${e.response?.statusCode})";
        if (errorData != null) {
          errorMsg += ": $errorData";
        } else if (e.message != null) {
          errorMsg += ": ${e.message}";
        }
        throw Exception(errorMsg);
      } catch (e) {
        LoggerService.error("Creation Error (General): $e", tag: 'TUS');
        throw Exception("Upload Initializing Error: $e");
      }
    }

    // 3. Upload Chunks (PATCH)
    final int actualChunkSize =
        chunkSize ?? (1 * 1024 * 1024); // Use passed size or default 1MB
    final RandomAccessFile raf = await file.open(mode: FileMode.read);

    try {
      while (offset < fileSize) {
        if (cancelToken?.isCancelled == true) {
          throw DioException(
            requestOptions: RequestOptions(path: uploadUrl),
            type: DioExceptionType.cancel,
            error: "User paused upload",
          );
        }

        // Read chunk
        await raf.setPosition(offset);
        int sizeToRead = actualChunkSize;
        if (offset + sizeToRead > fileSize) {
          sizeToRead = fileSize - offset;
        }

        final List<int> chunkData = await raf.read(sizeToRead);

        // Upload chunk
        try {
          final response = await _dio.patch(
            uploadUrl,
            data: chunkData,
            options: Options(
              validateStatus: (status) => status! < 500, // Don't throw for 400
              headers: {
                'Tus-Resumable': '1.0.0',
                'Upload-Offset': offset.toString(),
                'Content-Type': 'application/offset+octet-stream',
                'Content-Length': sizeToRead.toString(),
                'AccessKey': apiKey,
                'LibraryId': libraryId,
              },
            ),
            onSendProgress: (chunkSent, chunkTotal) {
              if (onProgress != null) {
                // Real-time calculation: completed chunks + current chunk progress
                onProgress(offset + chunkSent, fileSize);
              }
            },
            cancelToken: cancelToken,
          );

          if (response.statusCode != 204 && response.statusCode != 200) {
            throw Exception(
              "TUS PATCH Error (${response.statusCode}): ${response.data}",
            );
          }

          LoggerService.success(
            "Chunk Uploaded: $sizeToRead bytes at offset $offset",
            tag: 'TUS',
          );
        } on DioException catch (e) {
          LoggerService.error(
            "Chunk Patch Error: ${e.type} | ${e.error} | ${e.message}",
            tag: 'TUS',
          );
          LoggerService.error(
            "Context: Offset $offset, URL: $uploadUrl",
            tag: 'TUS',
          );
          rethrow;
        } catch (e) {
          LoggerService.error("Chunk General Error: $e", tag: 'TUS');
          rethrow;
        }

        offset += sizeToRead;
        if (onProgress != null) {
          onProgress(offset, fileSize);
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      await raf.close();
    }

    // Clear cache on success
    await _clearSession(fingerprint);
    return currentVideoId ?? videoId;
  }

  // Helper: Base64 Encode Metadata
  String base64EnFilename(String filePath) {
    final name = path.basename(filePath);
    return base64Encode(utf8.encode(name));
  }

  String base64EnFiletype(String filePath) {
    // Basic mapping, can be improved
    final ext = path.extension(filePath).toLowerCase();
    String type = 'application/octet-stream';
    if (ext == '.mp4') {
      type = 'video/mp4';
    } else if (ext == '.mov') {
      type = 'video/quicktime';
    }
    return base64Encode(utf8.encode(type));
  }

  Future<Map<String, String>?> _getSession(String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // 🔥 Force sync across isolates/restarts
    final url = prefs.getString('tus_url_$fingerprint');
    final vid = prefs.getString('tus_vid_$fingerprint');
    if (url != null) {
      return {'url': url, 'videoId': vid ?? ''};
    }
    return null;
  }

  Future<void> _saveSession(String fingerprint, String url, String? vid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tus_url_$fingerprint', url);
    if (vid != null) {
      await prefs.setString('tus_vid_$fingerprint', vid);
    }
  }

  Future<void> _clearSession(String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tus_url_$fingerprint');
    await prefs.remove('tus_vid_$fingerprint');
  }
}
