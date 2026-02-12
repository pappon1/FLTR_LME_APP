
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    validateStatus: (status) => true,
  ));

  final key = '47d150e7-c234-4267-85a4018657d5-afa6-4d5c';
  
  print('--- BUNNY DEEP PATH TEST ---');

  final endpoints = [
    'https://sg.storage.bunnycdn.com/lme-media-storage/', // Root with slash
    'https://sg.storage.bunnycdn.com/lme-media-storage',  // Root no slash
    'https://sg.storage.bunnycdn.com/lme-media-storage/courses/', // Subfolder
  ];

  for (var url in endpoints) {
    print('\nTesting URL: $url');
    final resp = await dio.get(
      url,
      options: Options(headers: {
        'AccessKey': key,
        'Accept': 'application/json',
      }),
    );
    print('Status: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      print('✅ SUCCESS! Content length: ${resp.data.toString().length}');
      // Print first 100 chars of data to see if it's a file list
      print('Data Snippet: ${resp.data.toString().substring(0, (resp.data.toString().length > 200 ? 200 : resp.data.toString().length))}');
    }
  }
}
