import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

class TusUploader {
  final Dio _dio = Dio();
  final String apiKey;
  final String libraryId;
  final String videoId;
  final String? collectionId;

  // Bunny Stream TUS Endpoint
  static const String _baseUrl = 'https://video.bunnycdn.com/tusupload';

  TusUploader({
    required this.apiKey,
    required this.libraryId,
    required this.videoId,
    this.collectionId,
  });

  /// Uploads a file using TUS protocol with Resume capability
  Future<String> upload(
    File file, {
    Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
    int? chunkSize, // Optional chunk size
  }) async {
    if (libraryId.isEmpty) {
      LoggerService.error(
        "LibraryId is empty. Configure Bunny Stream library.",
        tag: 'TUS',
      );
      throw Exception("LibraryId missing or invalid.");
    }
    final int fileSize = await file.length();
    final String filename = path.basename(file.path);
    // Include videoId and libraryId in fingerprint to ensure we always get the RIGHT session
    final String fingerprint = "$filename-$fileSize-$libraryId-$videoId";
    LoggerService.info("Using LibraryId: $libraryId", tag: 'TUS');

    // 1. Check for existing upload URL (Resume)
    LoggerService.info(
      "Checking session for fingerprint: $fingerprint",
      tag: 'TUS',
    );
    final session = await _getSession(fingerprint);
    String? uploadUrl = session?['url'];
    String? currentVideoId = session?['videoId'];
    int offset = 0;

    // 🔥 Sanity Check: If currentVideoId looks like a TUS ID (tail of URL), INVALIDATE IT.
    if (uploadUrl != null && currentVideoId != null) {
      final uri = Uri.tryParse(uploadUrl);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final tusId = uri.pathSegments.last;
        if (currentVideoId == tusId) {
          LoggerService.warning(
            "Found corrupted session (VideoID == TusID). Invalidating...",
            tag: 'TUS',
          );
          uploadUrl = null; // Force reset
          currentVideoId = null;
          await _clearSession(fingerprint);
        }
      }
    }

    if (uploadUrl != null) {
      // Fix Relative Path if saved in old format
      if (uploadUrl.startsWith('/')) {
        uploadUrl = "https://video.bunnycdn.com$uploadUrl";
      }

      try {
        LoggerService.info("Verifying session: $uploadUrl", tag: 'TUS');
        Response headResponse;
        try {
          final int expire =
              (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 86400;
          final String vidForSig =
              (currentVideoId != null && currentVideoId!.isNotEmpty)
              ? currentVideoId!
              : videoId;
          final String sig = sha256
              .convert(utf8.encode("$libraryId$apiKey$expire$vidForSig"))
              .toString();
          headResponse = await _dio.head(
            uploadUrl,
            options: Options(
              headers: {
                'Tus-Resumable': '1.0.0',
                'AuthorizationSignature': sig,
                'AuthorizationExpire': expire.toString(),
                'VideoId': vidForSig,
                'LibraryId': libraryId,
              },
              validateStatus: (status) => status == 200 || status == 204,
            ),
          );
        } on DioException catch (e) {
          if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
            LoggerService.warning(
              "HEAD unauthorized with Signature. Retrying with AccessKey.",
              tag: 'TUS',
            );
            headResponse = await _dio.head(
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
          } else {
            rethrow;
          }
        }

        final serverOffset = headResponse.headers.value('Upload-Offset');
        LoggerService.info(
          "HEAD Response Headers: ${headResponse.headers}",
          tag: 'TUS',
        );
        if (serverOffset != null) {
          offset = int.parse(serverOffset);
          LoggerService.success(
            "Resuming from Server Offset: $offset bytes",
            tag: 'TUS',
          );
          if (onProgress != null) onProgress(offset, fileSize);
          // Try to recover GUID from Upload-Metadata if present
          final metaHdr =
              headResponse.headers.value('upload-metadata') ??
              headResponse.headers.value('Upload-Metadata');
          if (metaHdr != null && metaHdr.isNotEmpty) {
            try {
              final parts = metaHdr.split(',');
              for (final p in parts) {
                final kv = p.trim().split(' ');
                if (kv.length == 2 && kv[0].toLowerCase() == 'video_id') {
                  final decoded = utf8.decode(base64Decode(kv[1]));
                  if (decoded.isNotEmpty) {
                    currentVideoId = decoded;
                    LoggerService.info(
                      "Recovered GUID from HEAD metadata: $currentVideoId",
                      tag: 'TUS',
                    );
                    break;
                  }
                }
              }
            } catch (_) {}
          }
        } else {
          LoggerService.warning(
            "No Upload-Offset found in HEAD response.",
            tag: 'TUS',
          );
          uploadUrl = null; // Force fresh POST if session is invalid
        }
      } catch (e) {
        if (e is DioException &&
            (e.response?.statusCode == 404 || e.response?.statusCode == 410)) {
          LoggerService.warning(
            "TUS Session Expired (404). Starting fresh.",
            tag: 'TUS',
          );
          uploadUrl = null;
          await _clearSession(fingerprint);
        } else {
          LoggerService.error(
            "Network error during Handshake: $e. Cannot resume safely.",
            tag: 'TUS',
          );
          rethrow; // Don't fall back to 0% if it's just a network error!
        }
      }

      // Enforce policy on resume as well
      if (currentVideoId == null || currentVideoId!.isEmpty) {
        LoggerService.error(
          "❌ [POLICY] Existing TUS session has no GUID. Aborting resume.",
          tag: 'TUS',
        );
        throw Exception(
          "GUID_REQUIRED: Existing session missing video_id metadata.",
        );
      }
    }

    // 2. Create new Upload (POST) ONLY if we don't have a valid resume URL
    if (uploadUrl == null) {
      LoggerService.info(
        "No valid session found for $filename. Creating new POST.",
        tag: 'TUS',
      );
      try {
        // Pre-create video to guarantee GUID for reliable linking
        if (currentVideoId == null || currentVideoId!.isEmpty) {
          try {
            currentVideoId = await _precreateVideo(
              title: filename,
              collectionId: collectionId,
            );
            if (currentVideoId != null && currentVideoId!.isNotEmpty) {
              LoggerService.success(
                "🎯 [PRECREATE] Video GUID: $currentVideoId",
                tag: 'TUS',
              );
            } else {
              LoggerService.warning(
                "⚠️ [PRECREATE] Could not pre-create video GUID. Proceeding without it.",
                tag: 'TUS',
              );
            }
          } catch (e) {
            LoggerService.warning(
              "⚠️ [PRECREATE] Failed with error: $e. Proceeding without GUID.",
              tag: 'TUS',
            );
          }
        }

        // Enforce policy: Do not upload without a valid GUID
        if (currentVideoId == null || currentVideoId!.isEmpty) {
          LoggerService.error(
            "❌ [POLICY] GUID is required before starting TUS upload.",
            tag: 'TUS',
          );
          throw Exception("GUID_REQUIRED: Unable to obtain Bunny video GUID.");
        }

        final metadata = {
          'libraryid': base64Encode(utf8.encode(libraryId)),
          'title': base64EnFilename(file.path),
          'filetype': base64EnFiletype(file.path),
        };

        final _vidForMeta = (currentVideoId ?? '').isNotEmpty
            ? currentVideoId!
            : (videoId.isNotEmpty ? videoId : '');
        if (_vidForMeta.isNotEmpty) {
          metadata['video_id'] = base64Encode(utf8.encode(_vidForMeta));
        }

        if (collectionId != null && collectionId!.isNotEmpty) {
          metadata['collection'] = base64Encode(utf8.encode(collectionId!));
        }

        final metadataStr = metadata.entries
            .map((e) => "${e.key} ${e.value}")
            .join(",");
        final int expire =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 86400;
        final String sig = sha256
            .convert(utf8.encode("$libraryId$apiKey$expire${currentVideoId!}"))
            .toString();
        Map<String, String> headers = {
          'Tus-Resumable': '1.0.0',
          'Upload-Length': fileSize.toString(),
          'Upload-Metadata': metadataStr,
          'AuthorizationSignature': sig,
          'AuthorizationExpire': expire.toString(),
          'VideoId': currentVideoId!,
          'LibraryId': libraryId,
        };

        LoggerService.info(
          "🚀 [TUS_REQ] Initializing Upload at: $_baseUrl",
          tag: 'TUS',
        );
        final masked = {
          'Tus-Resumable': headers['Tus-Resumable']!,
          'Upload-Length': headers['Upload-Length']!,
          'Upload-Metadata': headers['Upload-Metadata']!,
          'AuthorizationSignature':
              headers['AuthorizationSignature']!.substring(0, 8) + '***',
          'AuthorizationExpire': headers['AuthorizationExpire']!,
          'VideoId': headers['VideoId']!,
          'LibraryId': headers['LibraryId']!,
        };
        LoggerService.info("🚀 [TUS_HEADERS] Sent: $masked", tag: 'TUS');

        Response response;
        try {
          response = await _dio.post(
            _baseUrl,
            options: Options(
              validateStatus: (status) => status == 200 || status == 201,
              headers: headers,
            ),
          );
        } on DioException catch (e) {
          if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
            LoggerService.warning(
              "POST unauthorized with Signature. Retrying with AccessKey.",
              tag: 'TUS',
            );
            final altHeaders = {
              'Tus-Resumable': headers['Tus-Resumable']!,
              'Upload-Length': headers['Upload-Length']!,
              'Upload-Metadata': headers['Upload-Metadata']!,
              'AccessKey': apiKey,
              'LibraryId': headers['LibraryId']!,
            };
            final altMasked = {
              'Tus-Resumable': altHeaders['Tus-Resumable']!,
              'Upload-Length': altHeaders['Upload-Length']!,
              'Upload-Metadata': altHeaders['Upload-Metadata']!,
              'AccessKey': apiKey.substring(0, 6) + '***',
              'LibraryId': altHeaders['LibraryId']!,
            };
            LoggerService.info(
              "🚀 [TUS_HEADERS_ALT] Sent: $altMasked",
              tag: 'TUS',
            );
            response = await _dio.post(
              _baseUrl,
              options: Options(
                validateStatus: (status) => status == 200 || status == 201,
                headers: altHeaders,
              ),
            );
          } else {
            rethrow;
          }
        }

        LoggerService.info(
          "📡 [TUS_DEBUG_RAW] Full Headers: ${response.headers.map}",
          tag: 'TUS',
        );
        LoggerService.info(
          "💎 [GUID_TRACE] RAW BODY FROM BUNNY: ${response.data}",
          tag: 'TUS',
        );

        uploadUrl = response.headers.value('Location');
        // Try getting ID candidates
        final headerId = response.headers.value('Stream-Media-Id');
        String? bodyGuid;
        if (response.data is Map) {
          bodyGuid =
              (response.data['guid'] ??
                      response.data['id'] ??
                      response.data['videoId'] ??
                      response.data['id_video'])
                  ?.toString();
        }

        // Pick canonical GUID: strictly enforce hyphenated format
        bool _isGuid(String? v) {
          if (v == null) return false;
          final re = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          );
          return re.hasMatch(v);
        }

        String? candidateId;
        if (_isGuid(bodyGuid)) {
          candidateId = bodyGuid;
          LoggerService.success(
            "⭐⭐⭐⭐⭐ [GUID_DETECTED] FOUND IN BODY: $candidateId ⭐⭐⭐⭐⭐",
            tag: 'TUS',
          );
        } else if (_isGuid(headerId)) {
          candidateId = headerId;
          LoggerService.success(
            "⭐⭐⭐⭐⭐ [GUID_DETECTED] FOUND IN HEADER: $candidateId ⭐⭐⭐⭐⭐",
            tag: 'TUS',
          );
        }

        if (candidateId != null && _isGuid(candidateId)) {
          currentVideoId = candidateId;
        }

        // Final Validated Check (Phase 1)
        if (currentVideoId == null ||
            currentVideoId!.isEmpty ||
            !_isGuid(currentVideoId)) {
          LoggerService.error(
            "❌ [GUID_TRACE] Creation completed but GUID invalid. Aborting upload.",
            tag: 'TUS',
          );
          throw Exception(
            "GUID_INVALID: Server did not provide a valid video GUID.",
          );
        }

        if (uploadUrl == null) {
          throw Exception("Server did not return a Location header.");
        }
        if (uploadUrl.startsWith('/')) {
          uploadUrl = "https://video.bunnycdn.com$uploadUrl";
        }

        LoggerService.info(
          "✅ [GUID_TRACE] FINAL SELECTION FOR UPLOAD: ${currentVideoId ?? 'UNKNOWN'}",
          tag: 'TUS',
        );
        await _saveSession(fingerprint, uploadUrl, currentVideoId);
        LoggerService.success("New Session Created: $uploadUrl", tag: 'TUS');
      } on DioException catch (e) {
        final errorData = e.response?.data;
        LoggerService.error(
          "Creation Error Status: ${e.response?.statusCode}",
          tag: 'TUS',
        );
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

        LoggerService.info(
          "Uploading Chunk: Offset $offset, Size $sizeToRead bytes...",
          tag: 'TUS',
        );
        final stopwatch = Stopwatch()..start();

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
                'LibraryId': libraryId,
                // Signature headers for PATCH
                'AuthorizationSignature': sha256
                    .convert(
                      utf8.encode(
                        "$libraryId$apiKey${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 86400}${currentVideoId ?? videoId}",
                      ),
                    )
                    .toString(),
                'AuthorizationExpire':
                    ((DateTime.now().millisecondsSinceEpoch ~/ 1000) + 86400)
                        .toString(),
                'VideoId': (currentVideoId ?? videoId),
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
            LoggerService.error(
              "TUS PATCH Server Error: Status=${response.statusCode}, Body=${response.data}",
              tag: 'TUS',
            );
            throw Exception(
              "TUS PATCH Error (${response.statusCode}): ${response.data}",
            );
          }

          stopwatch.stop();
          LoggerService.success(
            "Chunk Uploaded in ${stopwatch.elapsedMilliseconds}ms. New Offset: ${offset + sizeToRead}",
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
    // Final Validated Check (Phase 2, after upload). Ensure GUID, else resolve.
    bool _isGuid2(String? v) {
      if (v == null) return false;
      final re = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      return re.hasMatch(v);
    }

    if (!_isGuid2(currentVideoId)) {
      for (
        int i = 0;
        i < 5 && (currentVideoId == null || currentVideoId!.isEmpty);
        i++
      ) {
        final resolved = await _resolveGuidByTitle(
          fileName: filename,
          collectionId: collectionId,
        );
        if (resolved != null && resolved.isNotEmpty) {
          currentVideoId = resolved;
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
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

  /// Resolve the actual GUID by scanning Bunny Stream videos by title (and collection if available)
  Future<String?> _resolveGuidByTitle({
    required String fileName,
    String? collectionId,
  }) async {
    try {
      // Small delay to allow indexing on server
      await Future.delayed(const Duration(milliseconds: 300));
      Response resp;
      final String url = (collectionId != null && collectionId.isNotEmpty)
          ? 'https://video.bunnycdn.com/library/$libraryId/videos?collection=$collectionId&itemsPerPage=100&page=1'
          : 'https://video.bunnycdn.com/library/$libraryId/videos?itemsPerPage=100&page=1';
      try {
        resp = await _dio.get(
          url,
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'accept': 'application/json',
            },
          ),
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          resp = await _dio.get(
            url,
            options: Options(
              headers: {'AccessKey': apiKey, 'accept': 'application/json'},
            ),
          );
        } else {
          rethrow;
        }
      }
      if (resp.statusCode == 200 && resp.data is Map) {
        final List<dynamic> items = resp.data['items'] ?? [];
        for (final it in items) {
          try {
            final title = it['title']?.toString() ?? '';
            final guid = it['guid']?.toString();
            if (guid != null &&
                title.isNotEmpty &&
                title.toLowerCase().contains(
                  path.basename(fileName).toLowerCase(),
                )) {
              LoggerService.info(
                "Resolved GUID by title: $guid for '$title'",
                tag: 'TUS',
              );
              return guid;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      LoggerService.warning("GUID resolution failed: $e", tag: 'TUS');
    }
    return null;
  }

  /// Pre-create a video entry to obtain a GUID, improving TUS linkage reliability
  Future<String?> _precreateVideo({
    required String title,
    String? collectionId,
  }) async {
    try {
      final url = 'https://video.bunnycdn.com/library/$libraryId/videos';
      final payload = <String, dynamic>{
        'title': title,
        if (collectionId != null && collectionId.isNotEmpty)
          'collectionId': collectionId,
      };
      Response resp;
      try {
        resp = await _dio.post(
          url,
          data: payload,
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            validateStatus: (s) => s == 200 || s == 201,
          ),
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          resp = await _dio.post(
            url,
            data: payload,
            options: Options(
              headers: {
                'AccessKey': apiKey,
                'accept': 'application/json',
                'content-type': 'application/json',
              },
              validateStatus: (s) => s == 200 || s == 201,
            ),
          );
        } else {
          rethrow;
        }
      }
      if (resp.data is Map) {
        final String? guid =
            (resp.data['guid'] ??
                    resp.data['id'] ??
                    resp.data['videoId'] ??
                    resp.data['id_video'])
                ?.toString();
        if (guid != null && guid.isNotEmpty) {
          return guid;
        }
      }
    } catch (e) {
      LoggerService.warning("Video pre-create failed: $e", tag: 'TUS');
    }
    return null;
  }
}
