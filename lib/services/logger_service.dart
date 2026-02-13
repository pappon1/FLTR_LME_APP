import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class LoggerService {
  static bool _enabled = true;
  static int _minIntervalMs = 50;
  static final Map<String, int> _lastTagTs = {};
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }
  static void setThrottleMs(int ms) {
    _minIntervalMs = ms;
  }
  static bool _allow(String tag) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastTagTs[tag] ?? 0;
    final ok = now - last >= _minIntervalMs;
    if (ok) _lastTagTs[tag] = now;
    return ok;
  }
  static void log(
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode && _enabled) {
      final tag = name ?? 'APP';
      if (!_allow(tag)) return;
      debugPrint('[$tag] $message');
      if (error != null) debugPrint('[$tag] ERROR: $error');
      
      developer.log(
        message,
        name: tag,
        error: error,
        stackTrace: stackTrace,
        time: DateTime.now(),
      );
    }
  }

  static void info(String message, {String? tag}) {
    log('ℹ️ $message', name: tag ?? 'INFO');
  }

  static void success(String message, {String? tag}) {
    log('✅ $message', name: tag ?? 'SUCCESS');
  }

  static void warning(String message, {String? tag, Object? error}) {
    log('⚠️ $message', name: tag ?? 'WARNING', error: error);
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      '❌ $message',
      name: tag ?? 'ERROR',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
