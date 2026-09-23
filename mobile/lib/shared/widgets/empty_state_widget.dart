import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.action,
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
              icon,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spaceM),
            Text(
              title,
              style: AppTheme.titleLarge.copyWith(color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceS),
            Text(
              description,
              style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppTheme.spaceL),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
