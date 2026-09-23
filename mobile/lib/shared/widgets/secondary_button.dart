import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/core/extensions/context_extensions.dart';

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final buttonWidth = width ?? double.infinity;

    return SizedBox(
      width: buttonWidth,
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceL, vertical: 14),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: AppTheme.spaceS),
                  ],
                  Text(
                    label,
                    style: AppTheme.buttonText.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
