import 'dart:convert';

class ContentClipboard {
  static List<Map<String, dynamic>>? items;
  static String action = '';

  static void copy(List<Map<String, dynamic>> newItems) {
    items = newItems
        .map((e) => Map<String, dynamic>.from(jsonDecode(jsonEncode(e))))
        .toList();
    action = 'copy';
  }

  static void cut(List<Map<String, dynamic>> newItems) {
    items = newItems
        .map((e) => Map<String, dynamic>.from(jsonDecode(jsonEncode(e))))
        .toList();
    action = 'cut';
  }

  static void clear() {
    items = null;
    action = '';
  }

  static bool get isEmpty => items == null || items!.isEmpty;
}
