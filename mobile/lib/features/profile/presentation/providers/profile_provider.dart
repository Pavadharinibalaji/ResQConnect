import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqconnect/core/logger/app_logger.dart';
import 'package:resqconnect/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:resqconnect/features/profile/domain/models/profile_model.dart';
import 'package:resqconnect/features/profile/domain/repositories/profile_repository.dart';
import 'package:resqconnect/shared/providers/global_providers.dart';

enum ProfileStatus { initial, loading, loaded, saving, saved, error }

class ProfileState {
  final ProfileStatus status;
  final ProfileModel profile;
  final String? errorMessage;

  const ProfileState({
    required this.status,
    required this.profile,
    this.errorMessage,
  });

  factory ProfileState.initial() => ProfileState(
        status: ProfileStatus.initial,
        profile: ProfileModel.initial(),
      );

  ProfileState copyWith({
    ProfileStatus? status,
    ProfileModel? profile,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(ProfileState.initial()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(status: ProfileStatus.loading);
    try {
      final profile = await _repository.getProfile();
      state = state.copyWith(status: ProfileStatus.loaded, profile: profile);
      AppLogger.info('Profile loaded successfully for handle: @${profile.username}');
    } catch (e) {
      AppLogger.warning('Failed to load remote profile: $e');
      state = state.copyWith(
        status: ProfileStatus.loaded,
        profile: state.profile, // Keep draft
      );
    }
  }

  void updateDraft({
    String? displayName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? location,
    String? emergencyRole,
    List<String>? skills,
    double? responseRadiusKm,
    bool? emergencyAlertsEnabled,
    bool? nearbyAlertsEnabled,
    bool? criticalOverrideEnabled,
    bool? availabilityEnabled,
    bool? highUrgencySoundEnabled,
  }) {
    final updated = state.profile.copyWith(
      displayName: displayName,
      username: username,
      bio: bio,
      avatarUrl: avatarUrl,
      location: location,
      emergencyRole: emergencyRole,
      skills: skills,
      responseRadiusKm: responseRadiusKm,
      emergencyAlertsEnabled: emergencyAlertsEnabled,
      nearbyAlertsEnabled: nearbyAlertsEnabled,
      criticalOverrideEnabled: criticalOverrideEnabled,
      availabilityEnabled: availabilityEnabled,
      highUrgencySoundEnabled: highUrgencySoundEnabled,
    );
    state = state.copyWith(profile: updated, status: ProfileStatus.loaded, clearError: true);
  }

  Future<bool> saveProfile() async {
    final currentProfile = state.profile;

    // Frontend Inline Validations
    if (currentProfile.displayName.trim().isEmpty) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: 'Please enter your full name.',
      );
      return false;
    }

    if (currentProfile.username.isNotEmpty) {
      final handle = currentProfile.username.trim().replaceAll('@', '');
      final RegExp validHandleRegex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
      if (!validHandleRegex.hasMatch(handle)) {
        state = state.copyWith(
          status: ProfileStatus.error,
          errorMessage: 'Username must contain 3-30 letters, numbers, or underscores.',
        );
        return false;
      }
    }

    state = state.copyWith(status: ProfileStatus.saving, clearError: true);
    debugPrint('[DEBUG_PROFILE] Saving profile for ${currentProfile.displayName}...');

    try {
      final savedProfile = await _repository.updateProfile(currentProfile);
      state = state.copyWith(status: ProfileStatus.saved, profile: savedProfile);
      debugPrint('[DEBUG_PROFILE] Profile saved successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error saving profile', error: e);
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return ProfileRepositoryImpl(dioClient.instance, storage);
});

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileNotifier(repository);
});
