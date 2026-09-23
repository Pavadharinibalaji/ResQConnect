import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class ResQButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;
  final double? width;
  final double height;

  const ResQButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
    this.width,
    this.height = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonWidth = width ?? double.infinity;

    final baseButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: isSecondary ? theme.colorScheme.secondary : theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      minimumSize: Size(buttonWidth, height),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
    );

    return SizedBox(
      width: buttonWidth,
      height: height,
      child: ElevatedButton(
        style: baseButtonStyle,
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: AppTheme.spaceS),
                  ],
                  Text(
                    label,
                    style: AppTheme.buttonText.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
