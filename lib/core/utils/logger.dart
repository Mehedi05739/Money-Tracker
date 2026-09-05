import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Thin logging wrapper — keeps `print` out of feature code and strips itself
/// in release builds.
class AppLogger {
  const AppLogger._();

  static void d(Object? message, {String name = 'DEBUG'}) => _log(message, name);

  static void i(Object? message, {String name = 'INFO'}) => _log(message, name);

  static void w(Object? message, {String name = 'WARN'}) => _log(message, name);

  static void e(
    Object? message, {
    String name = 'ERROR',
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(message, name, error: error, stackTrace: stackTrace);

  static void _log(
    Object? message,
    String name, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    developer.log('$message', name: name, error: error, stackTrace: stackTrace);
  }
}
