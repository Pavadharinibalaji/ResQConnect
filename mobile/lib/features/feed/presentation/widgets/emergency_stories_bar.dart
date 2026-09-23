import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class EmergencyStoriesBar extends StatelessWidget {
  final Function(String title)? onStoryTap;
  final VoidCallback? onAddTap;

  const EmergencyStoriesBar({
    super.key,
    this.onStoryTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mockStories = [
      {'name': 'Fire Ops', 'status': 'LIVE', 'color': AppColors.statusLive, 'icon': Icons.local_fire_department_rounded},
      {'name': 'Metro EMS', 'status': 'RESPONDING', 'color': AppColors.statusResponding, 'icon': Icons.medical_services_rounded},
      {'name': 'Sector 4 NGO', 'status': 'VERIFIED', 'color': AppColors.statusVerified, 'icon': Icons.verified_rounded},
      {'name': 'Flood Unit', 'status': 'LIVE', 'color': AppColors.statusLive, 'icon': Icons.water_damage_rounded},
      {'name': 'Police Grid', 'status': 'RESOLVED', 'color': AppColors.statusResolved, 'icon': Icons.local_police_rounded},
      {'name': 'Red Cross', 'status': 'VERIFIED', 'color': AppColors.statusVerified, 'icon': Icons.volunteer_activism_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.statusLive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Live Around You',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Text(
                '6 Active Clusters',
                style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceS),

        SizedBox(
          height: 94,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceM),
            scrollDirection: Axis.horizontal,
            itemCount: mockStories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.darkCard : Colors.white,
                            border: Border.all(color: AppColors.primaryEmergencyRed, width: 2),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_rounded,
                            color: AppColors.primaryEmergencyRed,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Report Live',
                          style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final story = mockStories[index - 1];
              final ringColor = story['color'] as Color;
              final storyName = story['name'] as String;

              return GestureDetector(
                onTap: () {
                  if (onStoryTap != null) {
                    onStoryTap!(storyName);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ringColor, width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: ringColor.withValues(alpha: 0.15),
                          child: Icon(
                            story['icon'] as IconData,
                            color: ringColor,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 68,
                        child: Text(
                          storyName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
