import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
    this.onCancel,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: AppTheme.titleLarge),
      content: Text(content, style: AppTheme.bodyLarge),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (onCancel != null) onCancel!();
            Navigator.of(context).pop(false);
          },
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop(true);
          },
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
