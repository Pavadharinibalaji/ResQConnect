import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/core/providers/location_provider.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';
import 'package:resqconnect/features/feed/presentation/providers/incident_provider.dart';
import 'package:resqconnect/features/feed/presentation/widgets/emergency_stories_bar.dart';
import 'package:resqconnect/features/feed/presentation/widgets/incident_card.dart';
import 'package:resqconnect/features/feed/presentation/widgets/resq_sos_button.dart';
import 'package:resqconnect/features/profile/presentation/providers/profile_provider.dart';

class HomeDashboardPage extends ConsumerStatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  ConsumerState<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends ConsumerState<HomeDashboardPage> {
  bool _isAvailableToRespond = true;
  final List<double> _radiiOptions = [1.0, 3.0, 5.0, 10.0, 25.0];

  final List<Map<String, dynamic>> _mockIncidents = [
    {
      'id': 'inc-101',
      'title': 'Structure Fire & Smoke Trapped',
      'category': 'fire',
      'severity': 'critical',
      'location': 'Sector 4, Urban Valley (2nd Floor)',
      'distance': '0.8 km away',
      'time': '3m ago',
      'description': 'Heavy smoke reported from second floor residential apartment. Immediate ladder rescue required.',
      'responderCount': 24,
      'isVerified': true,
      'reporterName': 'Fire Station Grid 12',
    },
    {
      'id': 'inc-102',
      'title': 'Multi-Vehicle Collision',
      'category': 'medical',
      'severity': 'high',
      'location': 'Metro Overpass Express Highway',
      'distance': '2.1 km away',
      'time': '12m ago',
      'description': 'Traffic block with minor injuries. Paramedics dispatched to clear lane & administer first aid.',
      'responderCount': 8,
      'isVerified': true,
      'reporterName': 'Traffic Patrol Alpha',
    },
    {
      'id': 'inc-103',
      'title': 'Flash Flood Water Overflow',
      'category': 'flood',
      'severity': 'high',
      'location': 'Lowland Underpass Road',
      'distance': '4.5 km away',
      'time': '25m ago',
      'description': 'Water levels rising rapidly due to drainage overflow. Vehicles advised to reroute.',
      'responderCount': 15,
      'isVerified': false,
      'reporterName': 'Civic Observer',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final incidentState = ref.watch(incidentProvider);
    final locationState = ref.watch(locationProvider);

    final user = authState.user;
    final profile = profileState.profile;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayName = profile.displayName.isNotEmpty ? profile.displayName : (user?.name ?? 'Responder Unit');
    final locationText = profile.location.isNotEmpty ? profile.location : 'Sector 4, Metro Valley';
    final currentRadius = incidentState.selectedRadiusKm;

    final displayIncidents = incidentState.incidents.isNotEmpty
        ? incidentState.incidents.map((e) => e.toCardJson()).toList()
        : _mockIncidents;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(incidentProvider.notifier).fetchNearbyIncidents(
                  latitude: locationState.latitude,
                  longitude: locationState.longitude,
                  radiusKm: currentRadius,
                );
          },
          child: CustomScrollView(
            slivers: [
              // Top Instagram-Style Emergency Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceM),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/profile'),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primaryEmergencyRed,
                                child: Text(
                                  displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'R',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.near_me_rounded, size: 12, color: AppColors.primaryEmergencyRed),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '$locationText • ${currentRadius.toInt()} km radius',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Availability Status Pill Toggle
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isAvailableToRespond = !_isAvailableToRespond;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isAvailableToRespond
                                ? AppColors.safeEmerald.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            border: Border.all(
                              color: _isAvailableToRespond ? AppColors.safeEmerald : Colors.grey,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isAvailableToRespond ? AppColors.safeEmerald : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isAvailableToRespond ? 'AVAILABLE' : 'OFF DUTY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _isAvailableToRespond
                                      ? AppColors.safeEmerald
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // SOS Prominent Banner
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM, vertical: 4),
                  padding: const EdgeInsets.all(AppTheme.spaceM),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(color: AppColors.primaryEmergencyRed.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryEmergencyRed.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const ResQSosButton(),
                      const SizedBox(width: AppTheme.spaceM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instant Emergency SOS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.titleMedium.copyWith(
                                color: AppColors.primaryEmergencyRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hold 2 seconds to dispatch immediate GPS distress signal to nearby responders.',
                              style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceM)),

              // Stories Bar ("Live Around You")
              SliverToBoxAdapter(
                child: EmergencyStoriesBar(
                  onAddTap: () => context.push('/create'),
                  onStoryTap: (name) => context.push('/explore'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceS)),

              // Feed Header & Radius Chips Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Emergencies Near You',
                            style: AppTheme.titleLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune_rounded),
                            onPressed: () => context.push('/explore'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Radius Filter Horizontal Chips
                      SizedBox(
                        height: 36,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _radiiOptions.length,
                          itemBuilder: (context, index) {
                            final r = _radiiOptions[index];
                            final isSelected = currentRadius.toInt() == r.toInt();

                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: isSelected,
                                label: Text('${r.toInt()} km'),
                                selectedColor: AppColors.primaryEmergencyRed,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                                side: BorderSide(
                                  color: isSelected ? AppColors.primaryEmergencyRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                ),
                                onSelected: (val) {
                                  ref.read(incidentProvider.notifier).setSelectedRadius(r);
                                  ref.read(incidentProvider.notifier).fetchNearbyIncidents(
                                        latitude: locationState.latitude,
                                        longitude: locationState.longitude,
                                        radiusKm: r,
                                      );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Incident List Cards
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final incident = displayIncidents[index];
                      return ResQIncidentCard(
                        incident: incident,
                        onTap: () => context.push('/incident/${incident['id']}'),
                        onRespondTap: () => context.push('/incident/${incident['id']}'),
                        onMapTap: () => context.push('/explore'),
                      );
                    },
                    childCount: displayIncidents.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}
