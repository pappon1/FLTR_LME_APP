import 'package:shared_preferences/shared_preferences.dart';

class VideoPersistenceService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static double? getProgress(String path) {
    return _prefs?.getDouble('progress_$path');
  }

  static Future<void> saveProgress(String path, double ratio) async {
    await _prefs?.setDouble('progress_$path', ratio);
  }

  static Future<Map<String, double>> getAllProgress(List<String> paths) async {
    await init();
    final Map<String, double> progress = {};
    for (String path in paths) {
      final p = getProgress(path);
      if (p != null) progress[path] = p;
    }
    return progress;
  }
}
