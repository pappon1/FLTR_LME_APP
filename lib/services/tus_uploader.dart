import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<String> upload(File file, {
    Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final int fileSize = await file.length();
    // Unique ID for cache (Fingerprint)
    final String fingerprint = "${file.path}-$fileSize-$libraryId"; 
    
    // 1. Check for existing upload URL (Resume)
    final session = await _getSession(fingerprint);
    String? uploadUrl = session?['url'];
    String? currentVideoId = session?['videoId']; 
    int offset = 0;

    if (uploadUrl != null) {
      // Fix Relative Path if saved in old format
      if (uploadUrl.startsWith('/')) {
          uploadUrl = "https://video.bunnycdn.com$uploadUrl";
      }

      // Check current offset from server (HEAD)
      try {
        final headResponse = await _dio.head(
          uploadUrl,
          options: Options(
            headers: {
              'Tus-Resumable': '1.0.0',
              'AccessKey': apiKey,
              'LibraryId': libraryId, // ADDED
            }, 
          )
        );
        final serverOffset = headResponse.headers.value('Upload-Offset');
        if (serverOffset != null) {
          offset = int.parse(serverOffset);
          print("🔄 [TUS] Resuming upload from byte $offset");
        }
      } catch (e) {
        // If HEAD fails (e.g. 404), restart upload
        print("⚠️ [TUS] Resume failed, starting fresh. Error: $e");
        uploadUrl = null;
        offset = 0;
        currentVideoId = null;
      }
    }

    // 2. Create new Upload (POST) if not resuming
    if (uploadUrl == null) {
      try {
        // Prepare Metadata (Bunny Stream TUS)
        final metadata = {
           'libraryid': base64Encode(utf8.encode(libraryId)), // Redundant but safer
           'title': base64EnFilename(file.path),
           'filetype': base64EnFiletype(file.path),
        };
        
        // If we have a specific videoId (e.g. for replacing an existing video)
        if (videoId.isNotEmpty) {
           metadata['video_id'] = base64Encode(utf8.encode(videoId));
        }

        final metadataStr = metadata.entries.map((e) => "${e.key} ${e.value}").join(",");
        
        final headers = {
          'Tus-Resumable': '1.0.0',
          'Upload-Length': fileSize.toString(),
          'Upload-Metadata': metadataStr,
          'AccessKey': apiKey,
          'LibraryId': libraryId, // Restore as Header since it worked in Step 589
        };

        print("📡 [TUS] Creating Upload...");
        print("📡 [TUS] Metadata: $metadataStr");

        final response = await _dio.post(
          _baseUrl,
          options: Options(
            validateStatus: (status) => status! < 500,
            headers: headers,
          ),
        );

        if (response.statusCode != 201 && response.statusCode != 200) {
           throw Exception("TUS POST Error (${response.statusCode}): ${response.data}");
        }
        
        uploadUrl = response.headers.value('Location');
        currentVideoId = response.headers.value('Stream-Media-Id');

        if (uploadUrl == null) {
            throw Exception("TUS Error: Server did not return a Location header.");
        }

        // Fix Relative Path (Bunny returns /tusupload/...)
        if (uploadUrl.startsWith('/')) {
            uploadUrl = "https://video.bunnycdn.com$uploadUrl";
        }
        
        // Extract Video ID from URL if header was missing
        if (currentVideoId == null || currentVideoId.isEmpty) {
            currentVideoId = uploadUrl.split('/').last;
        }
        
        await _saveSession(fingerprint, uploadUrl, currentVideoId);
        print("🆕 [TUS] Created session: $uploadUrl | VideoID: $currentVideoId");
      } on DioException catch (e) {
        final errorData = e.response?.data;
        print("❌ [TUS] Creation Error Status: ${e.response?.statusCode}");
        print("❌ [TUS] Creation Error Body: $errorData");
        
        String errorMsg = "Upload Creation Failed (${e.response?.statusCode})";
        if (errorData != null) errorMsg += ": $errorData";
        else if (e.message != null) errorMsg += ": ${e.message}";
        
        throw Exception(errorMsg);
      } catch (e) {
        print("❌ [TUS] Creation Error (General): $e");
        throw Exception("Upload Initializing Error: $e");
      }
    }

    // 3. Upload Chunks (PATCH)
    const int chunkSize = 1 * 1024 * 1024; // 1MB for reliability
    final RandomAccessFile raf = await file.open(mode: FileMode.read);
    
    try {
      while (offset < fileSize) {
        if (cancelToken?.isCancelled == true) {
          throw DioException(requestOptions: RequestOptions(path: uploadUrl!), type: DioExceptionType.cancel, error: "User paused upload");
        }

        // Read chunk
        await raf.setPosition(offset);
        int sizeToRead = chunkSize;
        if (offset + sizeToRead > fileSize) {
           sizeToRead = fileSize - offset;
        }
        
        final List<int> chunkData = await raf.read(sizeToRead);

        // Upload chunk
        try {
          final response = await _dio.patch(
            uploadUrl!,
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
            cancelToken: cancelToken,
          );

          if (response.statusCode != 204 && response.statusCode != 200) {
              throw Exception("TUS PATCH Error (${response.statusCode}): ${response.data}");
          }

          print("✅ [TUS] Chunk Uploaded: $sizeToRead bytes at offset $offset");
        } on DioException catch (e) {
           print("❌ [TUS] Chunk Patch Error: ${e.type} | ${e.error} | ${e.message}");
           print("❌ [TUS] Context: Offset $offset, URL: $uploadUrl");
           rethrow;
        } catch (e) {
           print("❌ [TUS] Chunk General Error: $e");
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

  // Persistence for Resume (SharedPreferences)
  Future<Map<String, String>?> _getSession(String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
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
