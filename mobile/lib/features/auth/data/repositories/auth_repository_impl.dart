import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:resqconnect/config/env.dart';
import 'package:resqconnect/core/errors/api_error_parser.dart';
import 'package:resqconnect/core/errors/failures.dart';
import 'package:resqconnect/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:resqconnect/features/auth/domain/models/user_model.dart';
import 'package:resqconnect/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remoteDatasource;

  const AuthRepositoryImpl(this._remoteDatasource);

  @override
  Future<Map<String, dynamic>> verifyFirebaseToken(String idToken) async {
    try {
      debugPrint('[DEBUG_AUTH] Backend verify-firebase request starting');
      debugPrint('[DEBUG_AUTH] Backend base URL: ${Env.apiBaseUrl}/api/v1');
      final jsonResponse = await _remoteDatasource.verifyFirebaseToken(idToken);
      debugPrint('[DEBUG_AUTH] Backend verify-firebase response received');
      final data = jsonResponse['data'] as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;
      debugPrint('[DEBUG_AUTH] JWT fields extracted from backend response');
      return {
        'access_token': data['access_token'] as String,
        'refresh_token': data['refresh_token'] as String,
        'is_new_user': data['is_new_user'] as bool? ?? false,
        'user': UserModel.fromJson(userJson),
      };
    } on DioException catch (e) {
      debugPrint(
        '[DEBUG_AUTH] Backend verify-firebase HTTP failure | '
        'status=${e.response?.statusCode} | '
        // Parsed message only: validation error bodies echo submitted input (the ID token).
        'message=${ApiErrorParser.messageFromResponseData(e.response?.data, statusCode: e.response?.statusCode)}',
      );
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> refreshSession(String refreshToken) async {
    try {
      final jsonResponse = await _remoteDatasource.refreshSession(refreshToken);
      return jsonResponse['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _remoteDatasource.logout(refreshToken);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> logoutAll() async {
    try {
      await _remoteDatasource.logoutAll();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<UserModel> getMe() async {
    try {
      final jsonResponse = await _remoteDatasource.getMe();
      final data = jsonResponse['data'] as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> setupProfile({
    required String fullName,
    String? profilePhoto,
    required String role,
  }) async {
    try {
      final jsonResponse = await _remoteDatasource.setupProfile(
        fullName: fullName,
        profilePhoto: profilePhoto,
        role: role,
      );
      final data = jsonResponse['data'] as Map<String, dynamic>;
      return {
        'access_token': data['access_token'] as String,
        'user': UserModel.fromJson(data['user'] as Map<String, dynamic>),
      };
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Failure _handleDioError(DioException e) {
    if (e.response == null) {
      debugPrint('[DEBUG_AUTH] Backend connection error (${e.type.name})');
      debugPrint('[DEBUG_AUTH] Target: ${Env.apiBaseUrl}/api/v1');
      debugPrint('[DEBUG_AUTH] Error: ${e.error ?? e.message}');
    }
    // detail may be a string or a list of validation errors; the parser handles both.
    return ApiErrorParser.fromDioException(e);
  }
}
