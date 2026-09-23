import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/features/auth/presentation/pages/login_page.dart';
import 'package:resqconnect/features/auth/presentation/pages/otp_page.dart';
import 'package:resqconnect/features/auth/presentation/pages/profile_setup_page.dart';
import 'package:resqconnect/features/auth/presentation/pages/splash_page.dart';
import 'package:resqconnect/features/auth/presentation/pages/welcome_page.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';
import 'package:resqconnect/features/feed/presentation/pages/create_incident_page.dart';
import 'package:resqconnect/features/feed/presentation/pages/incident_detail_page.dart';
import 'package:resqconnect/features/settings/presentation/pages/settings_page.dart';
import 'package:resqconnect/shared/widgets/resq_app_shell.dart';
import 'package:resqconnect/shared/widgets/unknown_page.dart';

/// Notifies GoRouter when auth state changes without recreating the router.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final _routerRefreshNotifierProvider = Provider<_RouterRefreshNotifier>((ref) {
  return _RouterRefreshNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    errorBuilder: (context, state) => const UnknownPage(),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final status = authState.status;
      final location = state.uri.path;

      debugPrint('[DEBUG_ROUTER] Evaluating redirect | location: $location | status: $status');

      final isAuthPath =
          location == '/login' || location == '/otp' || location == '/welcome';
      final isSplashPath = location == '/';

      if (status == AuthStatus.initial || status == AuthStatus.loading) {
        if (location == '/login' || location == '/otp' || location == '/profile-setup') {
          return null;
        }
        if (isSplashPath) {
          return null;
        }
        return null;
      }

      if (status == AuthStatus.codeSent) {
        if (location != '/otp') {
          return '/otp';
        }
        return null;
      }

      if (status == AuthStatus.error) {
        if (location == '/otp' || location == '/login') {
          return null;
        }
        if (isSplashPath) {
          return '/login';
        }
        return null;
      }

      if (status == AuthStatus.unauthenticated) {
        if (!isAuthPath && !isSplashPath) {
          return '/welcome';
        }
        return null;
      }

      if (status == AuthStatus.profileSetupRequired) {
        if (location != '/profile-setup') {
          return '/profile-setup';
        }
        return null;
      }

      if (status == AuthStatus.authenticated) {
        if (isAuthPath || isSplashPath || location == '/profile-setup') {
          return '/home';
        }
        return null;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpPage(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupPage(),
      ),

      // Authenticated ResQAppShell Routes
      GoRoute(
        path: '/home',
        builder: (context, state) => const ResQAppShell(initialIndex: 0),
      ),
      GoRoute(
        path: '/explore',
        builder: (context, state) => const ResQAppShell(initialIndex: 1),
      ),
      GoRoute(
        path: '/create',
        builder: (context, state) => const ResQAppShell(initialIndex: 2),
      ),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const ResQAppShell(initialIndex: 3),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ResQAppShell(initialIndex: 4),
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) => const CreateIncidentPage(),
      ),
      GoRoute(
        path: '/incident/:id',
        builder: (context, state) {
          final incidentId = state.pathParameters['id'] ?? 'inc-101';
          return IncidentDetailPage(incidentId: incidentId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
