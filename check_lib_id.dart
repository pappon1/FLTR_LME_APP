
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() {
  final _masterKey = encrypt.Key.fromUtf8('LME_OFFICIAL_SECURE_2026_BY_AIDM');
  final _iv = encrypt.IV(Uint8List(16));
  final _encrypter = encrypt.Encrypter(encrypt.AES(_masterKey));

  final libEnc = 'eOt8R2kk9tlm1BcOFMciOg==';
  final decrypted = _encrypter.decrypt64(libEnc, iv: _iv);
  print('Decrypted Library ID: $decrypted');
}
