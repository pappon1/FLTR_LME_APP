
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
  final videoId = 'bdde993f45154de4abfa07db911ecedf'; // From logs

  print('Library ID: $libId');
  print('Stream Key: $streamKey');

  final dio = Dio();
  try {
    final response = await dio.get(
      'https://video.bunnycdn.com/library/$libId/videos/$videoId',
      options: Options(
        headers: {
          'AccessKey': streamKey,
          'accept': 'application/json',
        },
      ),
    );
    print('Video Status: ${response.data['status']}');
    print('Video Title: ${response.data['title']}');
    print('Encoding Progress: ${response.data['encodeProgress']}%');
    print('Video Data: ${response.data}');
  } catch (e) {
    print('Error fetching video: $e');
  }
}
