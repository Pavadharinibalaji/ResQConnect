import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool showDragHandle;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool showDragHandle = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AppBottomSheet(
        title: title,
        showDragHandle: showDragHandle,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM, vertical: AppTheme.spaceM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDragHandle)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppTheme.spaceM),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (title != null) ...[
              Text(
                title!,
                style: AppTheme.titleLarge.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: AppTheme.spaceM),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
