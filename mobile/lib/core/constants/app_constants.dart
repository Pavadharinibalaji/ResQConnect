import 'package:resqconnect/config/env.dart';

class AppConstants {
  AppConstants._();

  // API Endpoints
  static String get baseApiUrl => '${Env.apiBaseUrl}/api/v1';
  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 15000;

  // Local Secure Storage Keys
  static const String keyAuthToken = 'resq_auth_token';
  static const String keyRefreshToken = 'resq_refresh_token';
  static const String keyUserUid = 'resq_user_uid';
  static const String keyUserPhone = 'resq_user_phone';
  static const String keyUserRole = 'resq_user_role';

  // UI Standard Margins & Paddings
  static const double marginSmall = 8.0;
  static const double marginMedium = 16.0;
  static const double marginLarge = 24.0;
  static const double marginXLarge = 32.0;

  // Visual Assets paths
  static const String logoIcon = 'assets/icons/resq_logo.png';
}
