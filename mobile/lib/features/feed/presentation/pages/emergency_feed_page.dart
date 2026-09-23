import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/feed/presentation/providers/incident_provider.dart';
import 'package:resqconnect/shared/widgets/resq_card.dart';

class EmergencyFeedPage extends ConsumerWidget {
  const EmergencyFeedPage({super.key});

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber.shade700;
      default:
        return Colors.blue;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      case 'flood':
        return Icons.water_damage_rounded;
      case 'crime':
        return Icons.local_police_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentState = ref.watch(incidentProvider);
    final incidents = incidentState.incidents;
    final isLoading = incidentState.status == IncidentStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Feed'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(incidentProvider.notifier).fetchIncidents(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(incidentProvider.notifier).fetchIncidents();
        },
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : (incidents.isEmpty
                ? const Center(child: Text('No active emergency incidents reported.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.spaceM),
                    itemCount: incidents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spaceM),
                    itemBuilder: (context, index) {
                      final incident = incidents[index];
                      final severityColor = _getSeverityColor(incident.severity);
                      final categoryIcon = _getCategoryIcon(incident.category);

                      return ResQCard(
                        title: Row(
                          children: [
                            Icon(categoryIcon, color: severityColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                incident.title,
                                style: AppTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          incident.address.isNotEmpty
                              ? incident.address
                              : 'Location: (${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)})',
                          style: AppTheme.bodyMedium.copyWith(color: Colors.grey.shade600),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              incident.description,
                              style: AppTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppTheme.spaceM),
                            Row(
                              children: [
                                Chip(
                                  label: Text(
                                    incident.severity.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  backgroundColor: severityColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    'Status: ${incident.status}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  avatar: const Icon(Icons.info_outline, size: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  )),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create'),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('REPORT'),
      ),
    );
  }
}
