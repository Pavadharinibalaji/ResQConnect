import 'package:flutter_test/flutter_test.dart';
import 'package:resqconnect/core/errors/failures.dart';
import 'package:resqconnect/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:resqconnect/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:resqconnect/features/auth/domain/models/user_model.dart';
import 'package:resqconnect/features/auth/domain/profile_roles.dart';

import '../../helpers/fake_http.dart';

Map<String, dynamic> _userJson({String role = 'citizen', Object? roles}) => {
      'id': '6f1c1d2e-0000-4000-8000-000000000001',
      'firebase_uid': 'fb-1',
      'phone_number': '+15550000001',
      'full_name': 'Test User',
      'role': role,
      'is_verified': true,
      'is_active': true,
      'created_at': '2026-09-24T10:00:00+00:00',
      if (roles != null) 'roles': roles,
    };

void main() {
  group('ProfileRoles.available', () {
    test('a new user is offered citizen and volunteer only', () {
      expect(ProfileRoles.available(const []), ['citizen', 'volunteer']);
      expect(ProfileRoles.available(const ['citizen']), ['citizen', 'volunteer']);
    });

    test('granted organisational roles are added', () {
      expect(ProfileRoles.available(const ['citizen', 'police']), ['citizen', 'volunteer', 'police']);
      expect(ProfileRoles.available(const ['ambulance', 'ngo', 'fire']),
          ['citizen', 'volunteer', 'ngo', 'fire', 'ambulance']);
    });

    test('organisational roles are never offered without a grant', () {
      for (final role in ProfileRoles.adminGranted) {
        expect(ProfileRoles.available(const ['volunteer']), isNot(contains(role)));
      }
    });

    test('admin is never selectable, even for an admin', () {
      expect(ProfileRoles.available(const ['admin']), isNot(contains('admin')));
      expect(ProfileRoles.available(const ['admin', 'police']), ['citizen', 'volunteer', 'police']);
    });

    test('unknown names are ignored and matching is case-insensitive', () {
      expect(ProfileRoles.available(const ['superadmin', 'police_officer', 'firefighter']), ['citizen', 'volunteer']);
      expect(ProfileRoles.available(const [' POLICE ']), ['citizen', 'volunteer', 'police']);
    });
  });

  group('ProfileRoles.effective', () {
    final newUser = ProfileRoles.available(const []);
    final policeUser = ProfileRoles.available(const ['police']);

    test('keeps an available role', () {
      expect(ProfileRoles.effective('volunteer', newUser), 'volunteer');
      expect(ProfileRoles.effective('police', policeUser), 'police');
      expect(ProfileRoles.effective('Police', policeUser), 'police');
    });

    test('falls back to citizen for unexpected, missing or ungranted roles', () {
      for (final role in [null, '', '   ', 'admin', 'superadmin', 'police', '💥']) {
        expect(ProfileRoles.effective(role, newUser), 'citizen', reason: '$role');
      }
    });
  });

  group('UserModel granted roles', () {
    test('parses the backend roles list', () {
      final user = UserModel.fromJson(_userJson(roles: [
        {'id': 'r1', 'name': 'citizen', 'description': null},
        {'id': 'r2', 'name': 'police', 'description': 'Police'},
      ]));
      expect(user.grantedRoles, ['citizen', 'police']);
    });

    test('missing or malformed roles never throw', () {
      expect(UserModel.fromJson(_userJson()).grantedRoles, isEmpty);
      expect(UserModel.fromJson(_userJson(roles: 'police')).grantedRoles, isEmpty);
      expect(UserModel.fromJson(_userJson(roles: [null, 3, {'name': 5}, {}, 'Fire'])).grantedRoles, ['fire']);
    });

    test('survives a toJson/fromJson round trip', () {
      final user = UserModel.fromJson(_userJson(roles: [{'name': 'ambulance'}]));
      final copy = UserModel.fromJson(user.toJson());
      expect(copy.grantedRoles, ['ambulance']);
      expect(copy, user);
    });
  });

  group('POST /auth/profile-setup through AuthRepositoryImpl', () {
    Future<Object> setup(FakeHttpAdapter adapter, String role) async {
      final repo = AuthRepositoryImpl(AuthRemoteDatasource(fakeDio(adapter)));
      try {
        return await repo.setupProfile(fullName: 'Test User', role: role);
      } catch (e) {
        return e;
      }
    }

    test('an ungranted organisational role is rejected with the backend reason', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse(
            {'detail': 'This role can only be granted by an administrator.'},
            403,
          ));
      final result = await setup(adapter, 'police');
      expect(result, isA<ServerFailure>());
      expect((result as ServerFailure).statusCode, 403);
      expect(result.message, 'This role can only be granted by an administrator.');
      expect(adapter.requests.single.data, containsPair('role', 'police'));
    });

    test('a 422 validation list becomes a readable message', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse({
            'success': false,
            'detail': [
              {'type': 'string_type', 'loc': ['body', 'role'], 'msg': 'Input should be a valid string', 'input': ['x']},
            ],
          }, 422));
      final result = await setup(adapter, 'citizen');
      expect(result, isA<ServerFailure>());
      expect((result as ServerFailure).message, 'Role: Input should be a valid string');
    });

    test('a granted role succeeds and the returned user carries its roles', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse({
            'success': true,
            'data': {
              'access_token': 'new-access-token',
              'user': _userJson(role: 'police', roles: [{'name': 'citizen'}, {'name': 'police'}]),
            },
          }, 200));
      final result = await setup(adapter, 'police') as Map<String, dynamic>;
      expect(result['access_token'], 'new-access-token');
      final user = result['user'] as UserModel;
      expect(user.role, 'police');
      expect(user.grantedRoles, ['citizen', 'police']);
    });

    test('GET /auth/me exposes granted roles for the selector', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse({
            'success': true,
            'data': _userJson(roles: [{'name': 'citizen'}, {'name': 'fire'}]),
          }, 200));
      final user = await AuthRepositoryImpl(AuthRemoteDatasource(fakeDio(adapter))).getMe();
      expect(ProfileRoles.available(user.grantedRoles), ['citizen', 'volunteer', 'fire']);
    });
  });
}
