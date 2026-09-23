import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/shared/widgets/primary_button.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Ambient Background Glows
          Positioned(
            top: -size.width * 0.2,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.1,
            left: -size.width * 0.3,
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.12),
              ),
            ),
          ),

          // Main Content Layer
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceL,
                  vertical: AppTheme.spaceM,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppTheme.spaceM),

                    // Glowing Brand Avatar Badge
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceL),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 32,
                            spreadRadius: 4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceL),

                    // App Title
                    Text(
                      'ResQConnect',
                      style: AppTheme.headlineLarge.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceXS),

                    // Tagline
                    Text(
                      '“When people need help, People respond.”',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.secondary,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceXL),

                    // Glassmorphism Highlight Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spaceL),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Real-Time Network',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTheme.spaceM),
                              Text(
                                'Instant Community Relief',
                                style: AppTheme.headlineMedium.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spaceXS),
                              Text(
                                'Connect with nearby citizens, volunteer responders, and official emergency services in real time.',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceXXL),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: PrimaryButton(
                        label: 'Get Started',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () => context.go('/login'),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceM),

                    // Footer Shield Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Verified Emergency Network',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}