import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class RazorpayService {
  static const String _baseUrl = 'https://api.razorpay.com/v1';

  Future<Map<String, String?>> getKeys() async {
    final doc = await FirebaseFirestore.instance.collection('settings').doc('razorpay_keys').get();
    if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
            'key_id': data['key_id'],
            'key_secret': data['key_secret'],
        };
    }
    return {'key_id': null, 'key_secret': null};
  }

  Future<void> saveKeys(String keyId, String keySecret) async {
      await FirebaseFirestore.instance.collection('settings').doc('razorpay_keys').set({
          'key_id': keyId.trim(),
          'key_secret': keySecret.trim(),
      }, SetOptions(merge: true));
  }

  // Generic Get Request
  Future<dynamic> _get(String endpoint) async {
      final keys = await getKeys();
      if (keys['key_id'] == null || keys['key_id']!.isEmpty) {
          throw Exception('API Keys not configured. Please configure them in settings.');
      }

      final String basicAuth = 'Basic ${base64Encode(utf8.encode('${keys['key_id']}:${keys['key_secret']}'))}';

      final response = await http.get(
          Uri.parse('$_baseUrl$endpoint'),
          headers: {'Authorization': basicAuth},
      );

      if (response.statusCode == 200) {
          return jsonDecode(response.body);
      } else {
          throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
  }

  Future<Map<String, dynamic>> fetchSettlements() async {
      return await _get('/settlements?count=20');
  }

  Future<Map<String, dynamic>> fetchPayments() async {
      return await _get('/payments?count=20');
  }
  
  Future<Map<String, dynamic>> fetchBalance() async {
      // Note: Balance API might not be available to all merchants or requires different endpoint.
      // We will try standard endpoint or return dummy if fails.
      return {'balance': 0}; 
  }
}
