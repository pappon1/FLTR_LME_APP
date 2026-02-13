import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';
import 'security_service.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  FirebaseFirestore? _firestore;

  String? _bunnyStorageKey;
  String? _bunnyStreamKey;
  String? _bunnyLibraryId;

  bool _isInitialized = false;

  // 🎥 Bunny.net Video Stream CDN Pull Zone Hostname
  // NOTE: This is DIFFERENT from the Library ID. Library ID (e.g. 583681) is for API calls.
  static const String _bunnyStreamCdnHost = 'vz-6f779b00-3e0.b-cdn.net';

  // 🛡️ Security: Allowed Referer for Video Playback
  static const String allowedReferer = 'https://com.officialmobileengineer.app';

  // 🔐 ENCRYPTED FALLBACKS (Verified and Updated)
  static const String _fallbackStorageEnc =
      'eeQrQGQlmeRBvS83KuAcApHCKW8Rl0KiY8s1CNIR2jgh5rprNEhG3c8Qp1YwLl2z';
  static const String _fallbackStreamEnc =
      'fbctRWh2neJBv34wfOAcAMaQKW5Fl0P2ZcIzWINEizhwsL4+NEgS35sQp1YwLl2z';
  static const String _fallbackLibraryEnc = 'eOt8R2kk9tlm1BcOFMciOg==';

  Future<void> initialize() async {
    // Avoid re-initialization if already ready and keys are present
    if (_isInitialized &&
        _bunnyStorageKey != null &&
        _bunnyStorageKey!.isNotEmpty) {
      return;
    }

    try {
      debugPrint(
        "ℹ️ [CONFIG] Starting Initialization... User: ${FirebaseAuth.instance.currentUser?.uid ?? 'NOT_LOGGED_IN'}",
      );

      _firestore ??= FirebaseFirestore.instance;
      final docRef = _firestore!.collection('settings').doc('keys');
      // 🔥 Pro-Tip: Force SERVER source during high-stakes init to avoid cache corruption on slow net
      final doc = await docRef
          .get(const GetOptions(source: Source.server))
          .timeout(
            const Duration(seconds: 25),
          ); // Increased timeout for slow hotspot

      final security = SecurityService();
      final Map<String, dynamic>? data = doc.exists ? doc.data() : null;

      if (data != null) {
        debugPrint(
          "ℹ️ [CONFIG] Keys fetched from SERVER. Fields: ${data.keys.toList()}",
        );

        final storageEnc = data['bunny_storage_key'] ?? data['storage_key'];
        final streamEnc = data['bunny_stream_key'] ?? data['stream_key'];
        final libraryEnc = data['bunny_library_id'] ?? data['library_id'];

        _bunnyStorageKey = security.decrypt(storageEnc);
        _bunnyStreamKey = security.decrypt(streamEnc);
        _bunnyLibraryId = security.decrypt(libraryEnc);

        if (_bunnyStorageKey == null || _bunnyStorageKey!.isEmpty) {
          debugPrint(
            "⚠️ [CONFIG] Decryption of Firestore keys returned empty values. Field 'bunny_storage_key' exists: ${data.containsKey('bunny_storage_key')}",
          );
        }
      } else {
        debugPrint(
          "⚠️ [CONFIG] Firestore keys missing in doc. Using internal fallbacks...",
        );
        _bunnyStorageKey = security.decrypt(_fallbackStorageEnc);
        _bunnyStreamKey = security.decrypt(_fallbackStreamEnc);
        _bunnyLibraryId = security.decrypt(_fallbackLibraryEnc);
      }

      if (_bunnyStorageKey != null && _bunnyStorageKey!.isNotEmpty) {
        _isInitialized = true;
        debugPrint(
          "✅ [CONFIG] Config Service Ready! StorageKey Length: ${_bunnyStorageKey!.length}",
        );
      } else {
        debugPrint(
          "❌ [CONFIG] Keys are still empty after all attempts. Falling through to catch...",
        );
        _isInitialized = false;
        throw Exception("Decryption produced empty keys.");
      }
    } catch (e) {
      LoggerService.error(
        "CONFIG_INIT_ERROR: $e. Attempting emergency local fallback...",
        tag: 'CONFIG',
      );
      _isInitialized = false;
      // Emergency Fallback if everything fails
      try {
        final security = SecurityService();
        _bunnyStorageKey =
            '47d150e7-c234-4267-85a4018657d5-afa6-4d5c'; // Verified User Override
        _bunnyStreamKey = security.decrypt(_fallbackStreamEnc);
        _bunnyLibraryId = security.decrypt(_fallbackLibraryEnc);

        if (_bunnyStorageKey != null && _bunnyStorageKey!.isNotEmpty) {
          _isInitialized = true;
          debugPrint("✅ [CONFIG] Emergency Fallback Success.");
        } else {
          debugPrint("❌ [CONFIG] Emergency Fallback also produced empty keys.");
        }
      } catch (e2) {
        LoggerService.error(
          "CRITICAL: Even emergency fallback failed: $e2",
          tag: 'CONFIG',
        );
      }
    }
  }

  /// Manually setup keys (useful for background isolates)
  void setupKeys({
    required String storageKey,
    required String streamKey,
    required String libraryId,
  }) {
    _bunnyStorageKey = storageKey;
    _bunnyStreamKey = streamKey;
    _bunnyLibraryId = libraryId;
    _isInitialized = true;
    LoggerService.info(
      "Configuration manually injected (Background Mode).",
      tag: 'CONFIG',
    );
  }

  String get bunnyStorageKey => _bunnyStorageKey ?? '';
  String get bunnyStreamKey => _bunnyStreamKey ?? '';
  String get bunnyLibraryId => _bunnyLibraryId ?? '';
  String get bunnyStreamCdnHost => _bunnyStreamCdnHost;
  bool get isReady => _isInitialized;
}
