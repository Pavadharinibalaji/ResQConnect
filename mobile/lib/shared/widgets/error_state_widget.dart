import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/shared/widgets/primary_button.dart';

class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorStateWidget({
    super.key,
    required this.title,
    required this.description,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 72,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppTheme.spaceM),
            Text(
              title,
              style: AppTheme.titleLarge.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceS),
            Text(
              description,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spaceL),
              PrimaryButton(
                label: retryLabel,
                onPressed: onRetry!,
                width: 150,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
