import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class ResQCard extends StatelessWidget {
  final Widget child;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final List<Widget>? actions;
  final double? width;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const ResQCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.actions,
    this.width,
    this.padding = const EdgeInsets.all(AppTheme.spaceM),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      color: backgroundColor ?? theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: width,
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || subtitle != null || trailing != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          DefaultTextStyle(
                            style: AppTheme.titleLarge.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                            child: title!,
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppTheme.spaceXS),
                          DefaultTextStyle(
                            style: AppTheme.bodyMedium.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            child: subtitle!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const Divider(height: AppTheme.spaceL),
            ],
            child,
            if (actions != null && actions!.isNotEmpty) ...[
              const Divider(height: AppTheme.spaceL),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
