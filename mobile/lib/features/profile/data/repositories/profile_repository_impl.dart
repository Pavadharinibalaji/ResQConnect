import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:resqconnect/config/env.dart';
import 'package:resqconnect/core/constants/app_constants.dart';
import 'package:resqconnect/core/errors/api_error_parser.dart';
import 'package:resqconnect/core/errors/failures.dart';
import 'package:resqconnect/core/logger/app_logger.dart';
import 'package:resqconnect/core/storage/secure_storage.dart';
import 'package:resqconnect/features/profile/domain/models/profile_model.dart';
import 'package:resqconnect/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final Dio _dio;
  final SecureStorage _secureStorage;

  ProfileRepositoryImpl(this._dio, this._secureStorage);

  static const String _storageKeyProfile = 'key_user_profile_cache';

  @override
  Future<ProfileModel> getProfile() async {
    if (Env.isDevAuthBypassEnabled) {
      final cachedJson = await _secureStorage.read(_storageKeyProfile);
      if (cachedJson != null) {
        try {
          return ProfileModel.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
        } catch (e) {
          AppLogger.warning('Failed to parse cached dev profile: $e');
        }
      }
    }

    try {
      final response = await _dio.get('${Env.apiBaseUrl}/api/v1/profile');
      final data = response.data['data'] as Map<String, dynamic>;
      final profile = ProfileModel.fromJson(data);
      await _secureStorage.write(_storageKeyProfile, jsonEncode(profile.toJson()));
      return profile;
    } on DioException catch (e) {
      AppLogger.warning('Backend GET /api/v1/profile failed: ${e.message}');
      if (Env.isDevAuthBypassEnabled) {
        final cachedJson = await _secureStorage.read(_storageKeyProfile);
        if (cachedJson != null) {
          return ProfileModel.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
        }
        return ProfileModel.initial();
      }
      throw _handleDioError(e);
    } catch (e) {
      throw ApiErrorParser.fromError(e, fallbackMessage: 'Unable to load your profile.');
    }
  }

  @override
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    final updatedProfile = profile.copyWith(
      profileCompleted: true,
      updatedAt: DateTime.now(),
    );

    if (Env.isDevAuthBypassEnabled) {
      await _secureStorage.write(_storageKeyProfile, jsonEncode(updatedProfile.toJson()));
      await _secureStorage.write(AppConstants.keyUserRole, updatedProfile.emergencyRole);
      debugPrint('[DEBUG_PROFILE] Profile saved locally in DEVELOPMENT mode');
      // Attempt backend push if reachable, but do not throw if LAN connection is isolated
      try {
        await _dio.put(
          '${Env.apiBaseUrl}/api/v1/profile',
          data: updatedProfile.toJson(),
        );
        debugPrint('[DEBUG_PROFILE] Remote profile synced successfully');
      } catch (e) {
        debugPrint('[DEBUG_PROFILE] Remote sync skipped in DEV mode (LAN unreachable): $e');
      }
      return updatedProfile;
    }

    try {
      final response = await _dio.put(
        '${Env.apiBaseUrl}/api/v1/profile',
        data: updatedProfile.toJson(),
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final result = ProfileModel.fromJson(data);
      // Stored only once the backend has accepted the profile (and its role).
      await _secureStorage.write(_storageKeyProfile, jsonEncode(result.toJson()));
      await _secureStorage.write(AppConstants.keyUserRole, result.emergencyRole);
      return result;
    } on DioException catch (e) {
      AppLogger.error('Backend PUT /api/v1/profile error', error: e);
      throw _handleDioError(e);
    } catch (e) {
      throw ApiErrorParser.fromError(e, fallbackMessage: 'Unable to save your profile.');
    }
  }

  @override
  Future<bool> checkProfileCompletion() async {
    try {
      final profile = await getProfile();
      return profile.profileCompleted;
    } catch (e) {
      return false;
    }
  }

  Failure _handleDioError(DioException e) {
    final failure = ApiErrorParser.fromDioException(e, fallbackMessage: 'Profile request failed.');
    if (e.response?.statusCode == 409) {
      return ValidationFailure(failure.message);
    }
    return failure;
  }
}
