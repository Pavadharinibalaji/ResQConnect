import 'package:resqconnect/features/profile/domain/models/profile_model.dart';

abstract class ProfileRepository {
  Future<ProfileModel> getProfile();
  Future<ProfileModel> updateProfile(ProfileModel profile);
  Future<bool> checkProfileCompletion();
}
