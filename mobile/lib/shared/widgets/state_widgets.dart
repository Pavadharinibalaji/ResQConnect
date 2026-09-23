import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class ResQEmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const ResQEmptyStateWidget({
    super.key,
    this.title = "You're All Clear",
    this.message = "No active emergencies reported within your radius.",
    this.icon = Icons.verified_user_rounded,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.safeEmerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppColors.safeEmerald),
            ),
            const SizedBox(height: AppTheme.spaceL),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppTheme.spaceXL),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmergencyRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ResQErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ResQErrorStateWidget({
    super.key,
    this.message = "Unable to load incidents. Check your connection and try again.",
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryEmergencyRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.primaryEmergencyRed),
            ),
            const SizedBox(height: AppTheme.spaceL),
            Text(
              "Connection Interrupted",
              style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceXL),
            if (onRetry != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryEmergencyRed),
                  foregroundColor: AppColors.primaryEmergencyRed,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('RETRY CONNECTION'),
              ),
          ],
        ),
      ),
    );
  }
}
