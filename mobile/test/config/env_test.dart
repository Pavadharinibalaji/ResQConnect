import 'package:flutter_test/flutter_test.dart';
import 'package:resqconnect/config/configuration_error_app.dart';
import 'package:resqconnect/config/env.dart';

// Every case passes explicit inputs, so results never depend on the --dart-define
// values of the test run or on the developer's machine.
EnvConfig _resolve(String appEnv, String bypass, {required bool release}) =>
    EnvConfig.resolve(appEnv: appEnv, devAuthBypass: bypass, isReleaseBuild: release);

void main() {
  group('development', () {
    test('can intentionally enable the bypass in a debug build', () {
      for (final appEnv in ['development', '', ' Development ']) {
        final config = _resolve(appEnv, 'true', release: false);
        expect(config.isValid, isTrue, reason: appEnv);
        expect(config.environment, AppEnvironment.dev);
        expect(config.devAuthBypass, isTrue);
      }
    });

    test('bypass is off unless explicitly requested', () {
      for (final bypass in ['', 'false', ' FALSE ']) {
        final config = _resolve('development', bypass, release: false);
        expect(config.isValid, isTrue);
        expect(config.devAuthBypass, isFalse, reason: bypass);
      }
    });

    test('an unconfigured debug build is development without the bypass', () {
      final config = _resolve('', '', release: false);
      expect((config.environment, config.devAuthBypass, config.error), (AppEnvironment.dev, false, null));
    });

    test('a development release build may run, but never with the bypass', () {
      expect(_resolve('development', 'false', release: true).isValid, isTrue);
      final config = _resolve('development', 'true', release: true);
      expect(config.isValid, isFalse);
      expect(config.devAuthBypass, isFalse);
      expect(config.error, contains('debug builds'));
    });
  });

  group('staging and production', () {
    for (final (appEnv, environment) in [('staging', AppEnvironment.staging), ('production', AppEnvironment.prod)]) {
      test('$appEnv disables the bypass in debug and release builds', () {
        for (final release in [false, true]) {
          for (final bypass in ['', 'false']) {
            final config = _resolve(appEnv, bypass, release: release);
            expect(config.isValid, isTrue);
            expect(config.environment, environment);
            expect(config.devAuthBypass, isFalse);
          }
        }
      });

      test('$appEnv with DEV_AUTH_BYPASS=true is refused, not silently ignored', () {
        for (final release in [false, true]) {
          final config = _resolve(appEnv, 'true', release: release);
          expect(config.isValid, isFalse);
          expect(config.devAuthBypass, isFalse);
          expect(config.error, contains('APP_ENV=development'));
        }
      });
    }
  });

  group('fail closed', () {
    test('a release build without APP_ENV does not fall back to development', () {
      for (final bypass in ['', 'false', 'true']) {
        final config = _resolve('', bypass, release: true);
        expect(config.isValid, isFalse, reason: bypass);
        expect(config.environment, AppEnvironment.prod);
        expect(config.devAuthBypass, isFalse);
        expect(config.error, contains('APP_ENV must be set'));
      }
    });

    test('unknown or malformed environments are rejected with the bypass off', () {
      for (final appEnv in ['dev', 'prod', 'develop', 'test', 'local', 'production2', 'staging production', '"production"']) {
        for (final release in [false, true]) {
          final config = _resolve(appEnv, 'true', release: release);
          expect(config.isValid, isFalse, reason: '$appEnv release=$release');
          expect(config.environment, AppEnvironment.prod);
          expect(config.devAuthBypass, isFalse);
        }
      }
    });

    test('malformed DEV_AUTH_BYPASS values are rejected, never read as true', () {
      for (final bypass in ['1', 'yes', 'on', 'TRUE!', 'tru', 'null']) {
        final config = _resolve('development', bypass, release: false);
        expect(config.isValid, isFalse, reason: bypass);
        expect(config.devAuthBypass, isFalse);
        expect(config.error, 'DEV_AUTH_BYPASS must be true or false.');
      }
    });

    test('an invalid configuration never enables the bypass', () {
      final appEnvs = ['', 'development', 'staging', 'production', 'bogus'];
      final bypasses = ['', 'true', 'false', 'maybe'];
      for (final appEnv in appEnvs) {
        for (final bypass in bypasses) {
          for (final release in [false, true]) {
            final config = _resolve(appEnv, bypass, release: release);
            if (config.devAuthBypass) {
              expect(config.isValid, isTrue);
              expect(config.environment, AppEnvironment.dev);
              expect(release, isFalse);
              expect(bypass, 'true');
            }
            if (!config.isValid) expect(config.devAuthBypass, isFalse);
          }
        }
      }
    });
  });

  test('resolution is deterministic', () {
    for (final args in [('production', '', true), ('', 'true', false), ('bogus', 'x', true), ('staging', 'false', false)]) {
      final first = _resolve(args.$1, args.$2, release: args.$3);
      final second = _resolve(args.$1, args.$2, release: args.$3);
      expect((second.environment, second.devAuthBypass, second.error), (first.environment, first.devAuthBypass, first.error));
    }
  });

  testWidgets('an invalid configuration shows the error screen instead of the app', (tester) async {
    const message = 'APP_ENV must be set to development, staging or production for profile and release builds.';
    await tester.pumpWidget(const ConfigurationErrorApp(message: message));
    expect(find.text('This build of ResQConnect is not configured correctly.'), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  });
}
