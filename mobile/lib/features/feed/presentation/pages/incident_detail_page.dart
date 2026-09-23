import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:resqconnect/core/map/navigation_launcher.dart';
import 'package:resqconnect/core/map/resq_map_controller.dart';
import 'package:resqconnect/core/providers/location_provider.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/feed/domain/models/incident_model.dart';
import 'package:resqconnect/features/feed/domain/models/evidence_model.dart';
import 'package:resqconnect/features/feed/presentation/providers/incident_provider.dart';
import 'package:resqconnect/features/map/presentation/widgets/incident_map_marker.dart';
import 'package:resqconnect/features/map/presentation/widgets/resq_map_view.dart';
import 'package:resqconnect/features/feed/presentation/widgets/evidence_media.dart';

class IncidentDetailPage extends ConsumerStatefulWidget {
  final String incidentId;

  const IncidentDetailPage({
    super.key,
    required this.incidentId,
  });

  @override
  ConsumerState<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends ConsumerState<IncidentDetailPage> {
  /// Camera for the non-interactive location preview card.
  final ResQMapController _previewMapController = ResQMapController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(incidentProvider.notifier).fetchIncidentDetail(widget.incidentId);
    });
  }

  /// Hands the destination to whichever maps app the responder has installed.
  ///
  /// No routing API is called: ResQConnect only supplies the coordinate, so
  /// directions stay keyless and free of per-request billing.
  Future<void> _launchDirections(double lat, double lng, String title) async {
    final result = await NavigationLauncher.launchDirections(
      lat: lat,
      lng: lng,
      label: title,
    );

    if (!mounted || result == NavigationLaunchResult.launched) return;

    final message = result == NavigationLaunchResult.noHandler
        ? 'No maps app found. Install a navigation app to get directions.'
        : 'Could not open navigation. Coordinates: '
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'COPY',
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: '$lat, $lng'),
            );
          },
        ),
      ),
    );
  }

  void _showRespondConfirmationSheet(BuildContext context, IncidentModel incident, String distanceStr) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final isDark = theme.brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.all(AppTheme.spaceL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppTheme.spaceM),

              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.primaryEmergencyRed, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Respond to this emergency?',
                      style: AppTheme.headlineMedium.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceM),

              Container(
                padding: const EdgeInsets.all(AppTheme.spaceM),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(color: AppColors.primaryEmergencyRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.navigation_rounded, color: AppColors.primaryEmergencyRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You are approximately $distanceStr from scene.',
                            style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ensure your personal safety before heading to location.',
                            style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceXL),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryEmergencyRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        final success = await ref.read(incidentProvider.notifier).respondToIncident(incident.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? "🚨 You're now marked as responding to this emergency!"
                                    : "Unable to join emergency response. Please try again.",
                              ),
                              backgroundColor: success ? AppColors.safeEmerald : AppColors.primaryEmergencyRed,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: const Text("CONFIRM & RESPOND", style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _showStatusUpdateSheet(BuildContext context, IncidentModel incident) {
    final currentStatus = incident.userResponderStatus ?? 'responding';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (sheetContext) {
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

              Text('Update Response Status', style: AppTheme.headlineMedium.copyWith(fontSize: 20)),
              const SizedBox(height: 4),
              Text('Current State: ${currentStatus.toUpperCase()}', style: AppTheme.bodySmall.copyWith(color: AppColors.safeEmerald, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppTheme.spaceL),

              _buildStatusOptionTile(
                sheetContext,
                title: 'ARRIVED AT SCENE',
                subtitle: 'Confirm you have reached the emergency coordinates.',
                icon: Icons.pin_drop_rounded,
                color: AppColors.warmSignalAmber,
                isSelected: currentStatus == 'arrived',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ref.read(incidentProvider.notifier).updateResponderStatus(incident.id, 'arrived');
                },
              ),
              _buildStatusOptionTile(
                sheetContext,
                title: 'ASSISTING VICTIMS',
                subtitle: 'Actively offering aid, rescue, or first aid.',
                icon: Icons.health_and_safety_rounded,
                color: AppColors.safeEmerald,
                isSelected: currentStatus == 'assisting',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ref.read(incidentProvider.notifier).updateResponderStatus(incident.id, 'assisting');
                },
              ),
              _buildStatusOptionTile(
                sheetContext,
                title: 'RESPONSE COMPLETED',
                subtitle: 'Safe resolution or handed over to official authorities.',
                icon: Icons.check_circle_rounded,
                color: Colors.blue,
                isSelected: currentStatus == 'completed',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ref.read(incidentProvider.notifier).updateResponderStatus(incident.id, 'completed');
                },
              ),
              const Divider(),
              _buildStatusOptionTile(
                sheetContext,
                title: 'WITHDRAW FROM RESPONSE',
                subtitle: 'No longer able to assist at scene.',
                icon: Icons.exit_to_app_rounded,
                color: AppColors.primaryEmergencyRed,
                isSelected: currentStatus == 'withdrawn',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await ref.read(incidentProvider.notifier).withdrawResponse(incident.id);
                },
              ),
              const SizedBox(height: AppTheme.spaceM),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusOptionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: isSelected ? color : Colors.grey.shade300),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? color : null)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: isSelected ? Icon(Icons.check_circle, color: color, size: 20) : null,
      ),
    );
  }

  void _showMediaPreviewDialog(BuildContext context, IncidentEvidenceModel item) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(dialogCtx),
              ),
            ),
            if (item.type == 'photo')
              Flexible(
                child: AuthenticatedEvidenceImage(
                  fileUrl: item.fileUrl,
                  fit: BoxFit.contain,
                  foregroundColor: Colors.white70,
                ),
              )
            else
              // No in-app video player yet: nothing is fetched, so no unauthenticated request is made.
              Container(
                padding: const EdgeInsets.all(32),
                child: const Column(
                  children: [
                    Icon(Icons.video_library_rounded, color: AppColors.warmSignalAmber, size: 64),
                    SizedBox(height: 12),
                    Text(
                      'Video evidence playback is not yet available in the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidentState = ref.watch(incidentProvider);
    final locationState = ref.watch(locationProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final incident = incidentState.currentIncident ??
        incidentState.incidents.firstWhere(
          (item) => item.id == widget.incidentId,
          orElse: () => IncidentModel.initial().copyWith(
            id: widget.incidentId,
            title: 'Structure Fire & Smoke Trapped',
            description: 'Heavy smoke reported from second floor residential apartment. Immediate ladder rescue required.',
            address: 'Sector 4, Urban Valley (2nd Floor)',
            category: 'fire',
            severity: 'critical',
            status: 'reported',
          ),
        );

    final isCritical = incident.severity.toLowerCase() == 'critical';

    double distKm = incident.distanceKm ?? 1.2;
    if (locationState.status == LocationStatus.located) {
      final meters = Geolocator.distanceBetween(
        locationState.latitude,
        locationState.longitude,
        incident.latitude,
        incident.longitude,
      );
      distKm = meters / 1000.0;
    }
    final distanceStr = '${distKm.toStringAsFixed(1)} km away';

    final isUserResponding = incident.isUserResponding;
    final userRespStatus = incident.userResponderStatus;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Media App Bar
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            leading: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            actions: [
              CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCritical
                            ? [AppColors.deepEmergencyRed, AppColors.primaryEmergencyRed]
                            : [Colors.orange.shade800, AppColors.warmSignalAmber],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.warning_amber_rounded, size: 90, color: Colors.white24),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCritical ? AppColors.primaryEmergencyRed : AppColors.warmSignalAmber,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '🔴 ${incident.severity.toUpperCase()} EMERGENCY',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Incident Details Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Verification
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          incident.title,
                          style: AppTheme.headlineMedium.copyWith(fontSize: 22),
                        ),
                      ),
                      if (incident.isVerified)
                        const Icon(Icons.verified_rounded, color: AppColors.statusVerified, size: 24),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.primaryEmergencyRed, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${incident.address} • $distanceStr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceL),

                  // Status Timeline Card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Response Status Timeline', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                      if (incident.status != 'resolved')
                        TextButton.icon(
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: const Text('Resolve Incident', style: TextStyle(fontSize: 11)),
                          onPressed: () async {
                            await ref.read(incidentProvider.notifier).updateIncidentLifecycleStatus(incident.id, 'resolved');
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceS),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceM),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimelineNode('Reported', true, isCurrent: incident.status == 'reported'),
                        _buildTimelineNode('Verified', incident.status != 'reported', isCurrent: incident.status == 'verified'),
                        _buildTimelineNode('Active', incident.status == 'active' || incident.status == 'resolved', isCurrent: incident.status == 'active'),
                        _buildTimelineNode('Resolved', incident.status == 'resolved', isCurrent: incident.status == 'resolved'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXL),

                  // Description Section
                  Text('Incident Description', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    incident.description.isEmpty ? 'Emergency assistance requested at location.' : incident.description,
                    style: AppTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTheme.spaceXL),

                  // Photo & Video Evidence Gallery Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Emergency Evidence (${incident.evidence.length})', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceS),
                  if (incident.evidence.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceM),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.photo_library_outlined, color: AppColors.warmSignalAmber),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No Media Evidence Attached', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Reporters and responders can capture live photos/videos during creation.', style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: incident.evidence.length,
                        itemBuilder: (context, idx) {
                          final item = incident.evidence[idx];
                          return GestureDetector(
                            onTap: () => _showMediaPreviewDialog(context, item),
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                color: isDark ? AppColors.darkSurface : Colors.grey.shade200,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (item.type == 'photo')
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                      child: AuthenticatedEvidenceImage(
                                        fileUrl: item.fileUrl,
                                        compact: true,
                                      ),
                                    )
                                  else
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.play_circle_fill_rounded, color: AppColors.warmSignalAmber, size: 36),
                                          const SizedBox(height: 4),
                                          Text('VIDEO', style: AppTheme.bodySmall.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: AppTheme.spaceXL),

                  // People Responding Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('People Responding (${incident.responderCount})', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                      if (isUserResponding)
                        GestureDetector(
                          onTap: () => _showStatusUpdateSheet(context, incident),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.safeEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                              border: Border.all(color: AppColors.safeEmerald),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.edit_rounded, size: 12, color: AppColors.safeEmerald),
                                const SizedBox(width: 4),
                                Text(
                                  (userRespStatus ?? 'RESPONDING').toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.safeEmerald),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceS),

                  if (incident.responders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spaceM),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_outline_rounded, color: AppColors.primaryEmergencyRed),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Be the First Responder', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Dispatch your status to coordinate with nearby rescue units.', style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: incident.responders.map((resp) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(AppTheme.spaceM),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primaryEmergencyRed.withValues(alpha: 0.2),
                                child: Text(
                                  (resp.userName?.isNotEmpty == true) ? resp.userName![0].toUpperCase() : 'R',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryEmergencyRed),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(resp.userName ?? 'Community Responder', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified_rounded, size: 14, color: AppColors.statusVerified),
                                      ],
                                    ),
                                    Text(resp.emergencyRole?.toUpperCase() ?? 'VOLUNTEER', style: AppTheme.bodySmall.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: resp.status == 'arrived' || resp.status == 'assisting'
                                      ? AppColors.safeEmerald.withValues(alpha: 0.15)
                                      : AppColors.warmSignalAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                ),
                                child: Text(
                                  resp.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: resp.status == 'arrived' || resp.status == 'assisting'
                                        ? AppColors.safeEmerald
                                        : AppColors.warmSignalAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: AppTheme.spaceXL),

                  // Live location preview (OpenStreetMap) & GET DIRECTIONS
                  Text('Incident Location & Safe Zones', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppTheme.spaceS),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusL),
                      ),
                      child: Stack(
                        children: [
                          // Static preview: gestures are off so the card does
                          // not fight the page scroll.
                          ResQMapView(
                            controller: _previewMapController,
                            initialCenter: LatLng(
                              incident.latitude,
                              incident.longitude,
                            ),
                            initialZoom: 15.0,
                            interactive: false,
                            showAttribution: false,
                            markers: [
                              Marker(
                                point: LatLng(
                                  incident.latitude,
                                  incident.longitude,
                                ),
                                width: 38,
                                height: 48,
                                alignment: Alignment.topCenter,
                                child: IncidentMapMarker(
                                  severity: incident.severity,
                                  isSelected: true,
                                  semanticLabel: 'Incident location',
                                  onTap: () => _launchDirections(
                                    incident.latitude,
                                    incident.longitude,
                                    incident.title,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Licence attribution is mandatory for OSM tiles.
                          const Positioned(
                            left: 0,
                            bottom: 0,
                            child: MapAttributionBar(),
                          ),

                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black87 : Colors.white,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusFull),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                              child: Text(
                                '(${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)})',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),

                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.primaryEmergencyRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              icon: const Icon(Icons.near_me_rounded, size: 16),
                              label: const Text(
                                'GET DIRECTIONS',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () => _launchDirections(
                                  incident.latitude,
                                  incident.longitude,
                                  incident.title),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Action Bar with Dynamic Responder CTA & Navigation Buttons
      bottomSheet: Container(
        padding: const EdgeInsets.all(AppTheme.spaceM),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUserResponding ? AppColors.safeEmerald : AppColors.primaryEmergencyRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                ),
                onPressed: () {
                  if (isUserResponding) {
                    _showStatusUpdateSheet(context, incident);
                  } else {
                    _showRespondConfirmationSheet(context, incident, distanceStr);
                  }
                },
                icon: Icon(isUserResponding ? Icons.check_circle_rounded : Icons.navigation_rounded),
                label: Text(
                  _getCtaLabel(userRespStatus),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              icon: const Icon(Icons.near_me_rounded),
              onPressed: () => _launchDirections(incident.latitude, incident.longitude, incident.title),
              tooltip: 'Get Directions',
            ),
          ],
        ),
      ),
    );
  }

  String _getCtaLabel(String? status) {
    if (status == null || status == 'withdrawn') {
      return "I'M RESPONDING";
    }
    switch (status.toLowerCase()) {
      case 'arrived':
        return "ARRIVED AT SCENE";
      case 'assisting':
        return "ASSISTING VICTIMS";
      case 'completed':
        return "RESPONSE COMPLETED";
      default:
        return "YOU'RE RESPONDING";
    }
  }

  Widget _buildTimelineNode(String label, bool isDone, {required bool isCurrent}) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent
                ? AppColors.primaryEmergencyRed
                : (isDone ? AppColors.safeEmerald : Colors.grey.shade400),
          ),
          child: isDone
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? AppColors.primaryEmergencyRed : null,
          ),
        ),
      ],
    );
  }
}
