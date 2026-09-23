import 'package:flutter_test/flutter_test.dart';
import 'package:resqconnect/config/env.dart';
import 'package:resqconnect/core/constants/app_constants.dart';
import 'package:resqconnect/core/errors/failures.dart';
import 'package:resqconnect/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:resqconnect/features/profile/domain/models/profile_model.dart';

import '../../helpers/fake_http.dart';

// The production branch of ProfileRepositoryImpl only runs without the development
// auth bypass (the default; it is skipped under --dart-define=DEV_AUTH_BYPASS=true).
final String? _skipInBypass =
    Env.isDevAuthBypassEnabled ? 'Requires the development auth bypass to be off' : null;

void main() {
  final profile = ProfileModel.initial().copyWith(emergencyRole: 'police', username: '');

  test('PUT /profile with an ungranted role fails and stores nothing locally', () async {
    final storage = FakeSecureStorage();
    final adapter = FakeHttpAdapter((_) => jsonResponse(
          {'detail': 'This role can only be granted by an administrator.'},
          403,
        ));
    final repo = ProfileRepositoryImpl(fakeDio(adapter), storage);

    await expectLater(
      repo.updateProfile(profile),
      throwsA(isA<ServerFailure>()
          .having((f) => f.statusCode, 'statusCode', 403)
          .having((f) => f.message, 'message', 'This role can only be granted by an administrator.')),
    );
    expect(storage.values, isNot(contains(AppConstants.keyUserRole)));
  }, skip: _skipInBypass);

  test('PUT /profile validation errors are readable and never echo input', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse({
          'success': false,
          'detail': [
            {'type': 'value_error', 'loc': ['body', 'username'], 'msg': 'Value error, Username must be 3-30 characters long.', 'input': 'bad name!'},
          ],
        }, 422));
    final repo = ProfileRepositoryImpl(fakeDio(adapter), FakeSecureStorage());

    await expectLater(
      repo.updateProfile(profile),
      throwsA(isA<ServerFailure>().having((f) => f.message, 'message', 'Username must be 3-30 characters long.')),
    );
  }, skip: _skipInBypass);

  test('an accepted profile stores the role the backend returned', () async {
    final storage = FakeSecureStorage();
    final adapter = FakeHttpAdapter((_) => jsonResponse({
          'success': true,
          'data': {...profile.toJson(), 'emergency_role': 'police', 'profile_completed': true},
        }, 200));
    final saved = await ProfileRepositoryImpl(fakeDio(adapter), storage).updateProfile(profile);

    expect(saved.emergencyRole, 'police');
    expect(storage.values[AppConstants.keyUserRole], 'police');
  }, skip: _skipInBypass);
}
