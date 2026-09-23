import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';
import 'package:resqconnect/shared/widgets/primary_button.dart';

class AuthErrorPage extends ConsumerWidget {
  final String errorMessage;

  const AuthErrorPage({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 96,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppTheme.spaceL),
              Text(
                'Authentication Error',
                textAlign: TextAlign.center,
                style: AppTheme.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: AppTheme.spaceM),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXXL),
              PrimaryButton(
                label: 'Go to Welcome Screen',
                icon: Icons.refresh_rounded,
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/welcome');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
