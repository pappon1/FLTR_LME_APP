
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    validateStatus: (status) => true,
  ));

  final key = '47d150e7-c234-4267-85a4018657d5-afa6-4d5c';
  final fileUrl = 'https://sg.storage.bunnycdn.com/lme-media-storage/courses/1770738090269/thumbnails/thumb_1770738090259_1000001446.jpg';

  print('🚀 TESTING FILE DOWNLOAD WITHOUT REFERER...');
  
  try {
    final resp = await dio.get(
      fileUrl,
      options: Options(headers: {
        'AccessKey': key,
        // NO REFERER HERE
      }),
    );

    print('Status Code: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      print('✅ SUCCESS! File downloaded without Referer.');
      print('Data size: ${resp.data.toString().length}');
    } else {
      print('❌ FAILED! Status: ${resp.statusCode}');
    }

    print('\n🚀 TESTING FILE DOWNLOAD WITH REFERER...');
    final respRef = await dio.get(
      fileUrl,
      options: Options(headers: {
        'AccessKey': key,
        'Referer': 'https://com.officialmobileengineer.app',
      }),
    );
    print('Status Code: ${respRef.statusCode}');
  } catch (e) {
    print('❌ ERROR: $e');
  }
}
