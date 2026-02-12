
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    validateStatus: (status) => true,
  ));

  final keys = [
    '47d150e7-c234-4267-85a4018657d5-afa6-4d5c', // Key from user
    '0db49ca1-ac4b-40ae-9aa5d710ef1d-00ec-4077', // Key from Firestore Stream
  ];

  final zones = [
    'lme-media-storage',
    'official-mobile-engineer',
  ];

  final hosts = [
    'storage.bunnycdn.com',
    'sg.storage.bunnycdn.com',
  ];

  print('--- BUNNY AUTH PERMUTATION TEST ---');

  for (var key in keys) {
    print('\n🔑 Testing Key: ${key.substring(0, 8)}...');
    
    // Check if it's an Account API Key first
    final accResp = await dio.get(
      'https://api.bunny.net/storagezone',
      options: Options(headers: {'AccessKey': key}),
    );
    if (accResp.statusCode == 200) {
      print('✅ SUCCESS: This is a VALID ACCOUNT API KEY!');
      continue; 
    }

    for (var zone in zones) {
      for (var host in hosts) {
        final url = 'https://$host/$zone/';
        
        // TEST A: Without Referer
        final resp = await dio.get(
          url,
          options: Options(headers: {'AccessKey': key}),
        );

        if (resp.statusCode == 200) {
          print('✅ SUCCESS: Key works for Zone: $zone on Host: $host WITHOUT Referer');
        } else {
          print('❌ FAIL: Zone: $zone | Host: $host | WITHOUT Referer | Status: ${resp.statusCode}');
        }

        // TEST B: With Referer
        final respRef = await dio.get(
          url,
          options: Options(headers: {
            'AccessKey': key,
            'Referer': 'https://com.officialmobileengineer.app'
          }),
        );
        if (respRef.statusCode == 200) {
          print('✅ SUCCESS: Key works for Zone: $zone on Host: $host WITH Referer');
        } else {
          print('❌ FAIL: Zone: $zone | Host: $host | WITH Referer | Status: ${respRef.statusCode}');
        }
      }
    }
  }
}
