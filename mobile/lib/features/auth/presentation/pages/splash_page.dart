import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for the splash animation to show
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.authenticated) {
      context.go('/home');
    } else if (authState.status == AuthStatus.profileSetupRequired) {
      context.go('/profile-setup');
    } else if (authState.status == AuthStatus.codeSent) {
      context.go('/otp');
    } else {
      context.go('/welcome');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Icon(
                  Icons.campaign_rounded,
                  size: 100,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceL),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'ResQConnect',
                      style: AppTheme.headlineLarge.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceS),
                    Text(
                      '"When people need help, People respond."',
                      textAlign: TextAlign.center,
                      style: AppTheme.headlineMedium.copyWith(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceXXL),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
