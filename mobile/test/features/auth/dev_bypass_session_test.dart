import 'package:flutter_test/flutter_test.dart';
import 'package:resqconnect/config/env.dart';
import 'package:resqconnect/core/constants/app_constants.dart';
import 'package:resqconnect/features/auth/domain/models/user_model.dart';
import 'package:resqconnect/features/auth/domain/repositories/auth_repository.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';

import '../../helpers/fake_http.dart';

class _CountingAuthRepository implements AuthRepository {
  int getMeCalls = 0;

  @override
  Future<UserModel> getMe() async {
    getMeCalls++;
    throw StateError('The backend must not be called with a development token.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Runs whenever the bypass is disabled, i.e. the default `flutter test`.
final String? _skipWhenBypassOn =
    Env.isDevAuthBypassEnabled ? 'Only meaningful when the development auth bypass is disabled' : null;

void main() {
  for (final stored in [
    {AppConstants.keyAuthToken: 'dev-access-token', AppConstants.keyRefreshToken: 'dev-refresh-token'},
    {AppConstants.keyAuthToken: 'dev-access-token'},
    {AppConstants.keyAuthToken: 'stale-token', AppConstants.keyRefreshToken: 'dev-refresh-token'},
  ]) {
    test('a leftover development session is discarded without contacting the backend: ${stored.values}', () async {
      final storage = FakeSecureStorage({...stored, AppConstants.keyUserRole: 'police'});
      final repository = _CountingAuthRepository();
      final notifier = AuthNotifier(repository, storage);
      addTearDown(notifier.dispose);

      await pumpEventQueue();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.user, isNull);
      expect(repository.getMeCalls, 0);
      expect(storage.values, isEmpty);
    }, skip: _skipWhenBypassOn);
  }
}
