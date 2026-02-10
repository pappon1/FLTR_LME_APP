import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';
import 'security_service.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _bunnyStorageKey;
  String? _bunnyStreamKey;
  String? _bunnyLibraryId;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint("⚠️ [CONFIG] User not logged in. Proceeding anyway, but fetch may fail due to security rules.");
    }

    try {
      debugPrint("ℹ️ [CONFIG] Fetching configuration from Firestore...");
      final doc = await _firestore.collection('settings').doc('keys').get(const GetOptions(source: Source.server));
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final security = SecurityService();
          
          // These are encrypted in Firestore, MUST decrypt them.
          _bunnyStorageKey = security.decrypt(data['bunny_storage_key'] ?? data['storage_key']);
          _bunnyStreamKey = security.decrypt(data['bunny_stream_key'] ?? data['stream_key']);
          _bunnyLibraryId = security.decrypt(data['bunny_library_id'] ?? data['library_id']);

          _isInitialized = true;
          
          // Debugging info (Masked)
          final skMask = _bunnyStorageKey!.length > 8 ? "${_bunnyStorageKey!.substring(0, 4)}...${_bunnyStorageKey!.substring(_bunnyStorageKey!.length - 4)}" : "INVALID";
          final stMask = _bunnyStreamKey!.length > 8 ? "${_bunnyStreamKey!.substring(0, 4)}...${_bunnyStreamKey!.substring(_bunnyStreamKey!.length - 4)}" : "INVALID";
          
          LoggerService.success(
            "Config Loaded. StorageKey: $skMask, StreamKey: $stMask, LibraryId: $_bunnyLibraryId", 
            tag: 'CONFIG'
          );
        } else {
          LoggerService.warning("Configuration document 'settings/keys' exists but data is null!", tag: 'CONFIG');
        }
      } else {
        LoggerService.warning("Configuration document NOT FOUND in Firestore at 'settings/keys'. Ensure you have the document and correct permissions.", tag: 'CONFIG');
      }
    } catch (e) {
      LoggerService.error("FETCH CONFIG EXCEPTION: $e", tag: 'CONFIG');
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
  bool get isReady => _isInitialized;
}
