import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/shared/widgets/resq_button.dart';

class UnknownPage extends StatelessWidget {
  const UnknownPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppTheme.spaceL),
              Text(
                '404',
                style: AppTheme.headlineLarge.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceS),
              Text(
                'Oops! The page you are looking for does not exist.',
                textAlign: TextAlign.center,
                style: AppTheme.headlineMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXL),
              ResQButton(
                label: 'Go Home',
                onPressed: () => context.go('/home'),
                width: 200,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
