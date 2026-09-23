import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, staging, prod }

/// Build-time configuration resolved from `--dart-define` values.
///
/// * `APP_ENV`: `development`, `staging` or `production`. Optional only in debug
///   builds (defaults to development); required for profile/release builds.
/// * `DEV_AUTH_BYPASS`: `true` or `false` (default `false`). May only be `true` for
///   development debug builds.
///
/// Anything else is a configuration error: the bypass stays off, the environment is
/// treated as production, and the app refuses to start (see main.dart). There is no
/// silent fallback to development behaviour.
class EnvConfig {
  final AppEnvironment environment;
  final bool devAuthBypass;

  /// Why the build configuration is unusable, or null when it is valid.
  final String? error;

  const EnvConfig._(this.environment, this.devAuthBypass, this.error);

  bool get isValid => error == null;

  static const Map<String, AppEnvironment> _environments = {
    'development': AppEnvironment.dev,
    'staging': AppEnvironment.staging,
    'production': AppEnvironment.prod,
  };

  static EnvConfig _invalid(String error) => EnvConfig._(AppEnvironment.prod, false, error);

  /// Pure and deterministic: the same inputs always give the same configuration.
  static EnvConfig resolve({
    required String appEnv,
    required String devAuthBypass,
    required bool isReleaseBuild,
  }) {
    final envName = appEnv.trim().toLowerCase();
    final AppEnvironment environment;
    if (envName.isEmpty) {
      if (isReleaseBuild) {
        return _invalid('APP_ENV must be set to development, staging or production for profile and release builds.');
      }
      environment = AppEnvironment.dev;
    } else {
      final known = _environments[envName];
      if (known == null) {
        return _invalid('Unknown APP_ENV. Use development, staging or production.');
      }
      environment = known;
    }

    final bypassValue = devAuthBypass.trim().toLowerCase();
    if (bypassValue.isNotEmpty && bypassValue != 'true' && bypassValue != 'false') {
      return _invalid('DEV_AUTH_BYPASS must be true or false.');
    }
    final bypassRequested = bypassValue == 'true';
    if (bypassRequested && environment != AppEnvironment.dev) {
      return _invalid('DEV_AUTH_BYPASS is only allowed with APP_ENV=development.');
    }
    if (bypassRequested && isReleaseBuild) {
      return _invalid('DEV_AUTH_BYPASS is only allowed in debug builds.');
    }

    return EnvConfig._(environment, bypassRequested, null);
  }
}

class Env {
  static const String _appEnv = String.fromEnvironment('APP_ENV');
  static const String _devAuthBypass = String.fromEnvironment('DEV_AUTH_BYPASS');

  /// Profile and release builds are treated as release builds.
  static final EnvConfig config = EnvConfig.resolve(
    appEnv: _appEnv,
    devAuthBypass: _devAuthBypass,
    isReleaseBuild: !kDebugMode,
  );

  static AppEnvironment get environment => config.environment;

  /// Non-null when the build configuration is invalid; the app must not start.
  static String? get configurationError => config.error;

  static String get apiBaseUrl {
    const customBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }
    switch (environment) {
      case AppEnvironment.prod:
        return 'https://api.resqconnect.com';
      case AppEnvironment.staging:
        return 'https://staging-api.resqconnect.com';
      case AppEnvironment.dev:
        // PC LAN IP for physical Android device; override with --dart-define=API_BASE_URL=...
        return 'http://172.16.39.88:8000';
    }
  }

  /// Development authentication bypass.
  /// When true, physical-device testing can proceed from Firebase OTP directly to
  /// Profile Setup without requiring LAN reachability to the local FastAPI backend.
  /// Only ever true for an explicit `APP_ENV=development` (or unset) debug build with
  /// `DEV_AUTH_BYPASS=true`; never in staging, production or release builds.
  static bool get isDevAuthBypassEnabled => config.devAuthBypass;

  // Firebase Config Settings
  static const String webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: '');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
  static const String messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  static const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'resqconnect-6f4bd');
  static const String storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
}
