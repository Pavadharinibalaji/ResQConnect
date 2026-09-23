import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final dynamic title;
  final dynamic subtitle;
  final Widget? trailing;
  final List<Widget>? actions;
  final Color? color;
  final double elevation;

  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.actions,
    this.color,
    this.elevation = 2.0,
  });

  Widget _buildContent(BuildContext context, dynamic content, TextStyle defaultStyle) {
    if (content is Widget) return content;
    if (content is String) return Text(content, style: defaultStyle);
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: elevation,
      color: color ?? theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || subtitle != null || trailing != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          _buildContent(
                            context,
                            title,
                            AppTheme.titleLarge.copyWith(color: theme.colorScheme.onSurface),
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppTheme.spaceXS),
                          _buildContent(
                            context,
                            subtitle,
                            AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
