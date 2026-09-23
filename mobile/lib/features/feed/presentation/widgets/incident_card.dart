import 'package:flutter/material.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';

class ResQIncidentCard extends StatefulWidget {
  final Map<String, dynamic> incident;
  final VoidCallback? onTap;
  final VoidCallback? onRespondTap;
  final VoidCallback? onMapTap;

  const ResQIncidentCard({
    super.key,
    required this.incident,
    this.onTap,
    this.onRespondTap,
    this.onMapTap,
  });

  @override
  State<ResQIncidentCard> createState() => _ResQIncidentCardState();
}

class _ResQIncidentCardState extends State<ResQIncidentCard> {
  bool _isAcknowledged = false;
  bool _isSaved = false;

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AppColors.severityCritical;
      case 'high':
        return AppColors.severityHigh;
      case 'moderate':
        return AppColors.severityModerate;
      default:
        return AppColors.severityLow;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      case 'flood':
      case 'disaster':
        return Icons.tsunami_rounded;
      case 'crime':
        return Icons.local_police_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final incident = widget.incident;
    final title = incident['title'] as String? ?? 'Emergency Incident';
    final category = incident['category'] as String? ?? 'medical';
    final severity = incident['severity'] as String? ?? 'high';
    final location = incident['location'] as String? ?? 'Nearby Sector';
    final distance = incident['distance'] as String? ?? '1.2 km away';
    final time = incident['time'] as String? ?? '5m ago';
    final description = incident['description'] as String? ?? 'Emergency assistance requested.';
    final responderCount = incident['responderCount'] as int? ?? 0;
    final isVerified = incident['isVerified'] as bool? ?? true;
    final reporterName = incident['reporterName'] as String? ?? 'Civic Reporter';
    final userRespStatus = incident['userResponderStatus'] as String?;
    final isUserResponding = incident['isUserResponding'] as bool? ??
        (userRespStatus != null && userRespStatus != 'withdrawn');

    final severityColor = _getSeverityColor(severity);
    final categoryIcon = _getCategoryIcon(category);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceM),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Reporter + Severity Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: categoryIcon == Icons.local_fire_department_rounded
                              ? AppColors.primaryEmergencyRed.withValues(alpha: 0.2)
                              : Colors.blue.withValues(alpha: 0.2),
                          child: Icon(categoryIcon, color: severityColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      reporterName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.titleMedium.copyWith(fontSize: 14),
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded, color: AppColors.statusVerified, size: 16),
                                  ],
                                ],
                              ),
                              Text(
                                '$distance • $time',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Severity Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      border: Border.all(color: severityColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: severityColor),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          severity.toUpperCase(),
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceM),

              // Title & Location
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.titleLarge.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spaceM),

              // Media Snippet Preview Card
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.darkSurface, AppColors.darkCard]
                        : [Colors.grey.shade200, Colors.grey.shade100],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        categoryIcon,
                        size: 64,
                        color: severityColor.withValues(alpha: 0.2),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_alt_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$responderCount Responders Active',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceM),

              // Bottom Actions: Social interactions + Dynamic Responder CTA
              Row(
                children: [
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(6),
                    icon: Icon(
                      _isAcknowledged ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isAcknowledged ? AppColors.primaryEmergencyRed : theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() => _isAcknowledged = !_isAcknowledged);
                    },
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(6),
                    icon: Icon(
                      _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: _isSaved ? AppColors.warmSignalAmber : theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() => _isSaved = !_isSaved);
                    },
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(6),
                    icon: Icon(Icons.map_rounded, color: theme.colorScheme.onSurfaceVariant, size: 22),
                    onPressed: widget.onMapTap,
                  ),
                  const Spacer(),
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: widget.onRespondTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUserResponding ? AppColors.safeEmerald : AppColors.primaryEmergencyRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                      icon: Icon(isUserResponding ? Icons.check_circle_rounded : Icons.navigation_rounded, size: 16),
                      label: Text(
                        isUserResponding ? 'RESPONDING ✓' : "I'M RESPONDING",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
