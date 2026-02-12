
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() async {
  final _masterKey = encrypt.Key.fromUtf8('LME_OFFICIAL_SECURE_2026_BY_AIDM');
  final _iv = encrypt.IV(Uint8List(16));
  final _encrypter = encrypt.Encrypter(encrypt.AES(_masterKey));

  final streamEnc = 'fbctRWh2neJBv34wfOAcAMaQKW5Fl0P2ZcIzWINEizhwsL4+NEgS35sQp1YwLl2z';
  final libEnc = 'eOt8R2kk9tlm1BcOFMciOg==';
  
  final streamKey = _encrypter.decrypt64(streamEnc, iv: _iv);
  final libId = _encrypter.decrypt64(libEnc, iv: _iv);

  print('Library ID: $libId');
  print('Stream Key: $streamKey');

  final dio = Dio();
  try {
    // There is no direct public endpoint to get library settings via the Stream API 
    // without the management credentials, but let's try some common endpoints.
    final response = await dio.get(
      'https://video.bunnycdn.com/library/$libId',
      options: Options(
        headers: {
          'AccessKey': streamKey,
          'accept': 'application/json',
        },
      ),
    );
    print('Library Meta: ${response.data}');
  } catch (e) {
    print('Error fetching library: $e');
  }
}
