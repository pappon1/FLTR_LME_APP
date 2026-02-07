import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class LoggerService {
  static void log(
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      developer.log(
        message,
        name: name ?? 'APP',
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
