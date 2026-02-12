import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() {
  final masterKey = encrypt.Key.fromUtf8('LME_OFFICIAL_SECURE_2026_BY_AIDM');
  final iv = encrypt.IV(Uint8List(16));
  final encrypter = encrypt.Encrypter(encrypt.AES(masterKey));

  final storageEnc = 'eeQrQGQlmeRBvS83KuAcApHCKW8Rl0KiY8s1CNIR2jgh5rprNEhG3c8Qp1YwLl2z';
  final streamEnc = 'fbctRWh2neJBv34wfOAcAMaQKW5Fl0P2ZcIzWINEizhwsL4+NEgS35sQp1YwLl2z';
  
  try {
    print('Storage: ${encrypter.decrypt64(storageEnc, iv: iv)}');
    print('Stream: ${encrypter.decrypt64(streamEnc, iv: iv)}');
  } catch (e) {
    print('Error: $e');
  }
}
