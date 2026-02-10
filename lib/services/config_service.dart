import 'package:cloud_firestore/cloud_firestore.dart';
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

    try {
      LoggerService.info("Fetching Remote Config Keys...", tag: 'CONFIG');
      final doc = await _firestore.collection('settings').doc('keys').get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final security = SecurityService();
        
        // 🔥 Decrypting keys into memory
        _bunnyStorageKey = security.decrypt(data['bunny_storage_key']);
        _bunnyStreamKey = security.decrypt(data['bunny_stream_key']);
        _bunnyLibraryId = security.decrypt(data['bunny_library_id']);
        
        _isInitialized = true;
        LoggerService.success("Remote Config Keys Decrypted & Loaded ✅", tag: 'CONFIG');
      } else {
        LoggerService.error("Remote Config document 'settings/keys' NOT FOUND ❌", tag: 'CONFIG');
      }
    } catch (e) {
      LoggerService.error("Failed to load Remote Config: $e", tag: 'CONFIG');
    }
  }

  String get bunnyStorageKey => _bunnyStorageKey ?? '';
  String get bunnyStreamKey => _bunnyStreamKey ?? '';
  String get bunnyLibraryId => _bunnyLibraryId ?? '';
  bool get isReady => _isInitialized;
}
