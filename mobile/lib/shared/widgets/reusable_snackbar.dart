import 'package:flutter/material.dart';

enum SnackbarType { success, error, warning, info }

class ReusableSnackbar {
  ReusableSnackbar._();

  static void show({
    required BuildContext context,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Theme.of(context);
    
    Color bgColor;
    IconData icon;

    switch (type) {
      case SnackbarType.success:
        bgColor = Colors.green.shade700;
        icon = Icons.check_circle_outline_rounded;
        break;
      case SnackbarType.error:
        bgColor = theme.colorScheme.error;
        icon = Icons.error_outline_rounded;
        break;
      case SnackbarType.warning:
        bgColor = Colors.orange.shade800;
        icon = Icons.warning_amber_rounded;
        break;
      case SnackbarType.info:
        bgColor = theme.colorScheme.secondary;
        icon = Icons.info_outline_rounded;
        break;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.all(16),
      elevation: 4,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
