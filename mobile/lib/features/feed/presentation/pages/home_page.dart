import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';
import 'package:resqconnect/shared/widgets/app_card.dart';
import 'package:resqconnect/shared/widgets/responsive_layout.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // Watch for logout redirects
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated) {
        context.go('/welcome');
      }
    });

    final mockIncidents = [
      {
        'title': 'Flash Flood Alert',
        'location': 'Sector 4, Urban Valley',
        'severity': 'Critical',
        'icon': Icons.tsunami_rounded,
        'color': Colors.red,
        'responders': '12 active',
      },
      {
        'title': 'Structural Integrity Risk',
        'location': 'Metro Overpass Area',
        'severity': 'High',
        'icon': Icons.domain_disabled_rounded,
        'color': Colors.orange,
        'responders': '5 active',
      },
      {
        'title': 'Medical Supply Demand',
        'location': 'Community Center Clinic',
        'severity': 'Medium',
        'icon': Icons.medical_services_rounded,
        'color': Colors.blue,
        'responders': '8 active',
      },
    ];

    Widget buildDashboardContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Responder Console',
                    style: AppTheme.headlineLarge.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(
                    'Active session: ${authState.user?.phoneNumber ?? "Offline Coordinator"} (${authState.user?.role ?? "citizen"})',
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                onPressed: () => ref.read(authProvider.notifier).logout(),
                tooltip: 'Logout',
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceL),
          Text('Navigation Test shortcuts:', style: AppTheme.titleLarge),
          const SizedBox(height: AppTheme.spaceS),
          Wrap(
            spacing: AppTheme.spaceS,
            runSpacing: AppTheme.spaceS,
            children: [
              ActionChip(
                avatar: const Icon(Icons.list_alt_rounded, size: 16),
                label: const Text('Emergency Feed'),
                onPressed: () => context.push('/feed'),
              ),
              ActionChip(
                avatar: const Icon(Icons.person_outline_rounded, size: 16),
                label: const Text('Profile'),
                onPressed: () => context.push('/profile'),
              ),
              ActionChip(
                avatar: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Settings'),
                onPressed: () => context.push('/settings'),
              ),
              ActionChip(
                avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                label: const Text('Trigger 404 Route'),
                onPressed: () => context.push('/invalid-path-routing-test'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXL),
          Text('Live Emergency Feed Summary', style: AppTheme.titleLarge),
          const SizedBox(height: AppTheme.spaceM),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mockIncidents.length,
            itemBuilder: (context, index) {
              final incident = mockIncidents[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceM),
                key: ValueKey(incident['title']),
                child: AppCard(
                  title: Text(
                    incident['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(incident['location'] as String),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(incident['icon'] as IconData, size: 36, color: incident['color'] as Color),
                          const SizedBox(width: AppTheme.spaceM),
                          Expanded(
                            child: Text(
                              'Primary responders dispatched to scene. Coordinating with local emergency taskforce.',
                              style: AppTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceM),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Severity: ${incident['severity'] as String}',
                            style: TextStyle(
                              color: incident['color'] as Color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceL),
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.people_alt_rounded, size: 16),
                            label: Text(incident['responders'] as String),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ResQConnect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceM),
          child: ResponsiveLayout(
            mobile: buildDashboardContent(),
            tablet: Center(
              child: SizedBox(
                width: 600,
                child: buildDashboardContent(),
              ),
            ),
            desktop: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: buildDashboardContent(),
                ),
                const SizedBox(width: AppTheme.spaceXL),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('System Health', style: AppTheme.titleLarge),
                      const SizedBox(height: AppTheme.spaceM),
                      AppCard(
                        title: const Text('PostGIS Sync'),
                        subtitle: const Text('Database replication online'),
                        child: Text(
                          'Emergency mapping clusters synced 2 mins ago. Global health is normal.',
                          style: AppTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
