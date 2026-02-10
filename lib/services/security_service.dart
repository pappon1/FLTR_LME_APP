import 'package:encrypt/encrypt.dart' as encrypt;
import 'logger_service.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // 🔥 THE MASTER SALT/KEY
  // NOTE: In production, this can be further obfuscated using native C++ code (JNI/NDK)
  // as per your request for high-level security.
  static final _masterKey = encrypt.Key.fromUtf8(
    'LME_OFFICIAL_SECURE_2026_BY_AIDM',
  ); // 32 chars
  static final _iv = encrypt.IV.fromLength(16);

  static final _encrypter = encrypt.Encrypter(encrypt.AES(_masterKey));

  /// Decrypts a string that was encrypted with AES-256
  String decrypt(String? encryptedText) {
    if (encryptedText == null || encryptedText.isEmpty) return '';
    try {
      final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
      if (decrypted.isNotEmpty) {
        LoggerService.info("Value decrypted successfully", tag: 'SECURITY');
      }
      return decrypted;
    } catch (e) {
      LoggerService.error("Decryption Failed: $e", tag: 'SECURITY');
      return '';
    }
  }

  /// Encrypts a string (Use this once to get the encrypted strings for Firestore)
  String encryptText(String plainText) {
    try {
      final encrypted = _encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      LoggerService.error("Encryption Failed: $e", tag: 'SECURITY');
      return '';
    }
  }
}
