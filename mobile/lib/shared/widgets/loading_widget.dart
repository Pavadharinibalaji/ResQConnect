import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: AppTheme.spaceM),
              Text(
                message!,
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
