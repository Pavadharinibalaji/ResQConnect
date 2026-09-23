import 'package:flutter/material.dart';

/// Shown instead of the app when the build configuration is invalid (see [EnvConfig]).
///
/// Nothing else runs: no Firebase initialisation, no authentication, no API calls.
class ConfigurationErrorApp extends StatelessWidget {
  final String message;

  const ConfigurationErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQConnect',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_suggest_rounded, size: 56, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'This build of ResQConnect is not configured correctly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
