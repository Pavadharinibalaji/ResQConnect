import 'package:resqconnect/features/auth/domain/models/user_model.dart';

abstract class AuthRepository {
  /// Verifies a Firebase ID token and returns session token details and profile data
  Future<Map<String, dynamic>> verifyFirebaseToken(String idToken);

  /// Rotates session credentials using a refresh token
  Future<Map<String, dynamic>> refreshSession(String refreshToken);

  /// Performs logout from the active device
  Future<void> logout(String refreshToken);

  /// Performs logout from all connected devices
  Future<void> logoutAll();

  /// Retrieves details of the authenticated responder
  Future<UserModel> getMe();

  /// Updates user profile details after first registration
  Future<Map<String, dynamic>> setupProfile({
    required String fullName,
    String? profilePhoto,
    required String role,
  });
}
