import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AuthRemoteDatasource {
  final Dio _dio;

  const AuthRemoteDatasource(this._dio);

  Future<Map<String, dynamic>> verifyFirebaseToken(String idToken) async {
    debugPrint('[DEBUG_AUTH] HTTP POST /auth/verify-firebase starting');
    final response = await _dio.post(
      '/auth/verify-firebase',
      data: {'id_token': idToken},
    );
    debugPrint(
      '[DEBUG_AUTH] HTTP POST /auth/verify-firebase completed | status=${response.statusCode}',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refreshSession(String refreshToken) async {
    final response = await _dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post(
      '/auth/logout',
      data: {'refresh_token': refreshToken},
    );
  }

  Future<void> logoutAll() async {
    await _dio.post('/auth/logout-all');
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setupProfile({
    required String fullName,
    String? profilePhoto,
    required String role,
  }) async {
    final response = await _dio.post(
      '/auth/profile-setup',
      data: {
        'full_name': fullName,
        'profile_photo': profilePhoto,
        'role': role,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
