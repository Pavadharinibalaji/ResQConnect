import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceM),
        children: [
          _buildSectionHeader('EMERGENCY PREFERENCES'),
          ListTile(
            leading: const Icon(Icons.notifications_active_rounded, color: AppColors.primaryEmergencyRed),
            title: const Text('Critical Overriding Alerts'),
            subtitle: const Text('Sound loud alarms for high-risk hazards'),
            trailing: Switch(value: true, activeTrackColor: AppColors.primaryEmergencyRed, onChanged: (_) {}),
          ),
          ListTile(
            leading: const Icon(Icons.radar_rounded, color: AppColors.warmSignalAmber),
            title: const Text('Incident Coverage Radius'),
            subtitle: const Text('Currently set to 10 km'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {},
          ),
          const Divider(),

          _buildSectionHeader('LOCATION & PRIVACY'),
          ListTile(
            leading: const Icon(Icons.location_on_rounded, color: AppColors.safeEmerald),
            title: const Text('High-Accuracy Location Service'),
            subtitle: const Text('GPS tracking for live emergency dispatch'),
            trailing: Switch(value: true, activeTrackColor: AppColors.safeEmerald, onChanged: (_) {}),
          ),
          const Divider(),

          _buildSectionHeader('ACCOUNT & SYSTEM'),
          ListTile(
            leading: const Icon(Icons.security_rounded, color: Colors.blue),
            title: const Text('Emergency Contacts'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About ResQConnect v1.0'),
            subtitle: const Text('Emergency Response Social Network'),
          ),
          const SizedBox(height: AppTheme.spaceXL),

          // Logout Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepEmergencyRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
            ),
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('LOG OUT OF RESQCONNECT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryEmergencyRed, letterSpacing: 1.0),
      ),
    );
  }
}
