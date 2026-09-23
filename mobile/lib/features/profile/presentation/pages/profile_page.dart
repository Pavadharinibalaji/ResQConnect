import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';
import 'package:resqconnect/features/profile/presentation/providers/profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final user = authState.user;
    final profile = profileState.profile;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayName = profile.displayName.isNotEmpty ? profile.displayName : (user?.name ?? 'Responder Unit');
    final usernameHandle = profile.username.isNotEmpty ? profile.username : (user?.name?.toLowerCase().replaceAll(' ', '_') ?? 'responder_unit');
    final roleName = profile.emergencyRole.isNotEmpty ? profile.emergencyRole : (user?.role ?? 'citizen');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Responder Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: 'Edit Profile',
            onPressed: () => context.push('/profile-setup'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppTheme.spaceM),
            // Header Profile Avatar & Verification
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.primaryEmergencyRed,
                    child: Text(
                      displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'R',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.verified_rounded, color: AppColors.statusVerified, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Text(
              displayName,
              style: AppTheme.headlineMedium.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 2),
            Text(
              '@$usernameHandle',
              style: AppTheme.bodySmall.copyWith(color: AppColors.primaryEmergencyRed, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryEmergencyRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                roleName.toUpperCase(),
                style: const TextStyle(color: AppColors.primaryEmergencyRed, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: AppTheme.spaceM),

            // Capabilities Wrap Chips
            if (profile.skills.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: profile.skills.map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Text(
                        skill,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceM),
            ],

            // Reputation Badges
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBadgeChip('Trusted Responder', Icons.security_rounded, Colors.blue),
                  const SizedBox(width: 8),
                  _buildBadgeChip('Community Verified', Icons.verified_user_rounded, AppColors.safeEmerald),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceL),

            // Stats Row
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM),
              padding: const EdgeInsets.all(AppTheme.spaceM),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('14', 'Reported'),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  _buildStatColumn('42', 'Responses'),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  _buildStatColumn('${profile.responseRadiusKm.toInt()} km', 'Radius'),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceL),

            // Profile Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryEmergencyRed,
              labelColor: AppColors.primaryEmergencyRed,
              tabs: const [
                Tab(text: 'POSTS'),
                Tab(text: 'RESPONSES'),
                Tab(text: 'SAVED'),
              ],
            ),

            SizedBox(
              height: 300,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildResponseHistoryList(isDark),
                  _buildResponseHistoryList(isDark),
                  const Center(child: Text('No saved emergency items yet.')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(count, style: AppTheme.headlineMedium.copyWith(fontSize: 20, color: AppColors.primaryEmergencyRed)),
        Text(label, style: AppTheme.bodySmall),
      ],
    );
  }

  Widget _buildResponseHistoryList(bool isDark) {
    final history = [
      {'title': 'Structure Fire Evacuation', 'time': '12 mins ago', 'status': 'Resolved'},
      {'title': 'Flash Flood Support', 'time': '2 days ago', 'status': 'Resolved'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: isDark ? AppColors.darkCard : Colors.white,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.safeEmerald,
              child: Icon(Icons.check_rounded, color: Colors.white, size: 18),
            ),
            title: Text(item['title']!, style: AppTheme.titleMedium.copyWith(fontSize: 14)),
            subtitle: Text('Responded ${item['time']}'),
            trailing: Chip(
              label: Text(item['status']!, style: const TextStyle(color: Colors.white, fontSize: 10)),
              backgroundColor: AppColors.safeEmerald,
            ),
          ),
        );
      },
    );
  }
}
