import 'dart:developer' as developer;

class AppLogger {
  AppLogger._();

  static void debug(String message, {String tag = 'DEBUG'}) {
    developer.log('[ResQConnect] [$tag] $message');
  }

  static void info(String message, {String tag = 'INFO'}) {
    developer.log('[ResQConnect] [$tag] $message');
  }

  static void warning(String message, {String tag = 'WARNING'}) {
    developer.log('[ResQConnect] [$tag] WARNING: $message');
  }

  static void error(String message, {dynamic error, StackTrace? stackTrace, String tag = 'ERROR'}) {
    developer.log(
      '[ResQConnect] [$tag] ERROR: $message',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
