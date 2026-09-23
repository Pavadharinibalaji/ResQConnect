import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:resqconnect/core/map/resq_map_controller.dart';
import 'package:resqconnect/core/providers/location_provider.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/feed/domain/models/incident_model.dart';
import 'package:resqconnect/features/feed/presentation/providers/incident_provider.dart';
import 'package:resqconnect/features/feed/presentation/widgets/incident_card.dart';
import 'package:resqconnect/features/map/presentation/widgets/incident_map_marker.dart';
import 'package:resqconnect/features/map/presentation/widgets/resq_map_view.dart';

class ExploreMapPage extends ConsumerStatefulWidget {
  const ExploreMapPage({super.key});

  @override
  ConsumerState<ExploreMapPage> createState() => _ExploreMapPageState();
}

class _ExploreMapPageState extends ConsumerState<ExploreMapPage> {
  final ResQMapController _mapController = ResQMapController();

  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Critical',
    'Fire',
    'Medical',
    'Flood',
    'Crime',
  ];

  /// Highlighted pin, kept in sync when a list row is tapped.
  String? _selectedIncidentId;

  /// The first GPS fix usually lands after the map is already built. Recentre
  /// once when it does, but never again — re-centring later would fight the
  /// responder panning the map.
  bool _hasAutoCentered = false;

  /// Default view (Bengaluru) used until a GPS fix arrives.
  static const LatLng _defaultLocation = LatLng(12.9716, 77.5946);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final loc = ref.read(locationProvider);
      if (loc.status != LocationStatus.located) {
        ref.read(locationProvider.notifier).fetchCurrentLocation();
      }
      ref.read(incidentProvider.notifier).fetchIncidents();
    });
  }

  void _showMarkerDetailSheet(BuildContext context, IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return Padding(
          padding: const EdgeInsets.all(AppTheme.spaceL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceM),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmergencyRed
                          .withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      '🚨 ${incident.severity.toUpperCase()} EMERGENCY',
                      style: const TextStyle(
                        color: AppColors.primaryEmergencyRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${incident.responderCount} Responders',
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.safeEmerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                incident.title,
                style: AppTheme.headlineMedium
                    .copyWith(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: AppColors.primaryEmergencyRed),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      incident.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceM),

              Text(
                incident.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyMedium
                    .copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spaceXL),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryEmergencyRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text(
                        'VIEW INCIDENT DETAILS',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.push('/incident/${incident.id}');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceM),
            ],
          ),
        );
      },
    );
  }

  /// Recentres on the freshest GPS fix. Refreshes first, then reads the
  /// resulting state, so the camera never chases a stale coordinate.
  Future<void> _recenterOnUser() async {
    await ref.read(locationProvider.notifier).fetchCurrentLocation();
    if (!mounted) return;

    final loc = ref.read(locationProvider);
    _mapController.moveTo(
      LatLng(loc.latitude, loc.longitude),
      zoomLevel: 15.0,
    );
  }

  void _fitAllMarkers(List<IncidentModel> incidents, LatLng userPos) {
    final points = <LatLng>[
      userPos,
      for (final inc in incidents) LatLng(inc.latitude, inc.longitude),
    ];
    _mapController.fitCoordinates(
      points,
      // Leave room for the search bar above and the incident sheet below.
      padding: const EdgeInsets.only(top: 140, bottom: 260, left: 48, right: 48),
    );
  }

  void _focusIncident(IncidentModel incident) {
    setState(() => _selectedIncidentId = incident.id);
    _mapController.moveTo(
      LatLng(incident.latitude, incident.longitude),
      zoomLevel: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (_hasAutoCentered) return;
      if (next.status != LocationStatus.located) return;

      _hasAutoCentered = true;
      _mapController.moveTo(
        LatLng(next.latitude, next.longitude),
        zoomLevel: 14.5,
      );
    });

    final locationState = ref.watch(locationProvider);
    final incidentState = ref.watch(incidentProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasFix = locationState.status == LocationStatus.located;
    final userLatLng = hasFix
        ? LatLng(locationState.latitude, locationState.longitude)
        : _defaultLocation;

    // Category / severity filtering (unchanged behaviour).
    final filteredIncidents = incidentState.incidents.where((inc) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Critical') {
        return inc.severity.toLowerCase() == 'critical';
      }
      return inc.category.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();

    // Paint the least urgent first so critical pins end up on top.
    final sortedForDisplay = [...filteredIncidents]..sort(
        (a, b) => IncidentMarkerStyle.forSeverity(a.severity)
            .rank
            .compareTo(IncidentMarkerStyle.forSeverity(b.severity).rank),
      );

    final markers = <Marker>[
      Marker(
        key: const ValueKey('user_location'),
        point: userLatLng,
        width: 46,
        height: 46,
        alignment: Alignment.center,
        child: UserLocationMarker(isStale: !hasFix),
      ),
      for (final inc in sortedForDisplay)
        Marker(
          key: ValueKey(inc.id),
          point: LatLng(inc.latitude, inc.longitude),
          width: 38,
          height: 48,
          // Pin tip sits on the coordinate.
          alignment: Alignment.topCenter,
          child: IncidentMapMarker(
            severity: inc.severity,
            isSelected: _selectedIncidentId == inc.id,
            semanticLabel: '${inc.severity} incident: ${inc.title}',
            onTap: () {
              setState(() => _selectedIncidentId = inc.id);
              _showMarkerDetailSheet(context, inc);
            },
          ),
        ),
    ];

    // Visualise the active search radius so the filter is legible on the map.
    final radiusCircles = <CircleMarker>[
      CircleMarker(
        point: userLatLng,
        radius: incidentState.selectedRadiusKm * 1000,
        useRadiusInMeter: true,
        color: AppColors.primaryEmergencyRed.withValues(alpha: 0.07),
        borderColor: AppColors.primaryEmergencyRed.withValues(alpha: 0.45),
        borderStrokeWidth: 1.5,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          ResQMapView(
            controller: _mapController,
            initialCenter: userLatLng,
            initialZoom: 13.5,
            markers: markers,
            circles: radiusCircles,
            // Tapping bare map clears the highlighted pin.
            onTap: (_) {
              if (_selectedIncidentId != null) {
                setState(() => _selectedIncidentId = null);
              }
            },
            attributionAlignment: AttributionAlignment.bottomLeft,
          ),

          // Top Header & Search Bar with Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceM),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10)
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            color: AppColors.primaryEmergencyRed),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search incidents, responders, grid...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.center_focus_strong_rounded,
                              color: AppColors.primaryEmergencyRed),
                          onPressed: () =>
                              _fitAllMarkers(filteredIncidents, userLatLng),
                          tooltip: 'Fit All Markers',
                        ),
                        IconButton(
                          icon: const Icon(Icons.my_location_rounded,
                              color: AppColors.primaryEmergencyRed),
                          onPressed: _recenterOnUser,
                          tooltip: 'Center My Location',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category Filter Chips
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final f = _filters[index];
                        final isSelected = _selectedFilter == f;

                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(f),
                            selectedColor: AppColors.primaryEmergencyRed,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            backgroundColor:
                                isDark ? AppColors.darkCard : Colors.white,
                            onSelected: (val) =>
                                setState(() => _selectedFilter = f),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating GPS Lock FAB
          Positioned(
            right: 16,
            bottom: 300,
            child: FloatingActionButton.small(
              heroTag: 'fab_my_loc',
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              foregroundColor: AppColors.primaryEmergencyRed,
              onPressed: _recenterOnUser,
              child: const Icon(Icons.gps_fixed_rounded),
            ),
          ),

          // Draggable Bottom Sheet with Incidents List
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusXL)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 15)
                  ],
                ),
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppTheme.spaceM),
                  itemCount: filteredIncidents.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Emergency Incidents (${filteredIncidents.length})',
                                  style: AppTheme.titleMedium
                                      .copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Radius: ${incidentState.selectedRadiusKm.toInt()} km',
                                style: AppTheme.bodySmall.copyWith(
                                    color: AppColors.primaryEmergencyRed),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceM),
                        ],
                      );
                    }
                    final incident = filteredIncidents[index - 1];
                    return ResQIncidentCard(
                      incident: incident.toCardJson(),
                      onTap: () {
                        _focusIncident(incident);
                        _showMarkerDetailSheet(context, incident);
                      },
                      onRespondTap: () =>
                          context.push('/incident/${incident.id}'),
                      onMapTap: () => _focusIncident(incident),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
