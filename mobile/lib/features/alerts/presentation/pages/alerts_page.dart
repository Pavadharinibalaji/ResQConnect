import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _alerts = [
    {
      'id': 'alt-1',
      'category': 'critical',
      'title': 'CRITICAL ALERT: Structure Fire Broadcast',
      'subtitle': 'Sector 4, Urban Valley (2.4 km away)',
      'time': '2m ago',
      'isRead': false,
      'color': AppColors.primaryEmergencyRed,
      'icon': Icons.emergency_rounded,
    },
    {
      'id': 'alt-2',
      'category': 'nearby',
      'title': 'Nearby Paramedics Dispatched',
      'subtitle': 'Multi-Vehicle Collision • 4.1 km away',
      'time': '15m ago',
      'isRead': true,
      'color': AppColors.warmSignalAmber,
      'icon': Icons.medical_services_rounded,
    },
    {
      'id': 'alt-3',
      'category': 'response',
      'title': '12 Responders Joined Your Alert',
      'subtitle': 'Water Supply Evacuation Task',
      'time': '1h ago',
      'isRead': true,
      'color': AppColors.safeEmerald,
      'icon': Icons.people_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryEmergencyRed,
          labelColor: AppColors.primaryEmergencyRed,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Critical'),
            Tab(text: 'Nearby'),
            Tab(text: 'Response'),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceM),
        itemCount: _alerts.length,
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          final color = alert['color'] as Color;
          final isRead = alert['isRead'] as bool;

          return Dismissible(
            key: Key(alert['id'] as String),
            background: Container(
              color: AppColors.primaryEmergencyRed,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spaceM),
              padding: const EdgeInsets.all(AppTheme.spaceM),
              decoration: BoxDecoration(
                color: isRead
                    ? (isDark ? AppColors.darkCard : Colors.white)
                    : color.withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: isRead
                      ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                      : color.withValues(alpha: 0.4),
                  width: isRead ? 1 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(alert['icon'] as IconData, color: color, size: 22),
                  ),
                  const SizedBox(width: AppTheme.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['title'] as String,
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert['subtitle'] as String,
                          style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    alert['time'] as String,
                    style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
