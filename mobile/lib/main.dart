import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/configuration_error_app.dart';
import 'config/env.dart';
import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail closed: an invalid build configuration never starts the app (or its auth).
  final configurationError = Env.configurationError;
  if (configurationError != null) {
    debugPrint('[CONFIG] Invalid build configuration: $configurationError');
    runApp(ConfigurationErrorApp(message: configurationError));
    return;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: ResQConnectApp(),
    ),
  );
}

class ResQConnectApp extends ConsumerWidget {
  const ResQConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ResQConnect',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}