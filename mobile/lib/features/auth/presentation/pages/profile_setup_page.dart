import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/auth/domain/profile_roles.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';
import 'package:resqconnect/features/profile/presentation/providers/profile_provider.dart';
import 'package:resqconnect/shared/widgets/loading_widget.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6;

  // Form State
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;

  String _selectedRole = 'citizen';
  final Set<String> _selectedCapabilities = {'First Aid', 'Communication'};
  double _responseRadiusKm = 10.0;

  // Preferences
  bool _enableEmergencyNotifications = true;
  bool _enableNearbyAlerts = true;
  bool _enableCriticalAlerts = true;
  bool _defaultAvailableToRespond = true;
  bool _enableHighUrgencySound = true;

  @override
  void initState() {
    super.initState();
    final initialProfile = ref.read(profileProvider).profile;
    _nameController = TextEditingController(text: initialProfile.displayName);
    _usernameController = TextEditingController(text: initialProfile.username);
    _bioController = TextEditingController(text: initialProfile.bio);
    _locationController = TextEditingController(text: initialProfile.location.isEmpty ? 'Sector 4, Metro Valley' : initialProfile.location);

    // An unknown or no-longer-granted role falls back to citizen instead of breaking the screen.
    _selectedRole = ProfileRoles.effective(initialProfile.emergencyRole, _availableRoleIds);
    if (initialProfile.skills.isNotEmpty) {
      _selectedCapabilities.addAll(initialProfile.skills);
    }
    _responseRadiusKm = initialProfile.responseRadiusKm;

    _enableEmergencyNotifications = initialProfile.emergencyAlertsEnabled;
    _enableNearbyAlerts = initialProfile.nearbyAlertsEnabled;
    _enableCriticalAlerts = initialProfile.criticalOverrideEnabled;
    _defaultAvailableToRespond = initialProfile.availabilityEnabled;
    _enableHighUrgencySound = initialProfile.highUrgencySoundEnabled;
  }

  // Self-service roles plus organisational roles an admin granted (from /auth/me).
  // Display only: the backend rejects any role the user has not been granted.
  List<String> get _availableRoleIds =>
      ProfileRoles.available(ref.read(authProvider).user?.grantedRoles ?? const []);

  String get _effectiveRole => ProfileRoles.effective(_selectedRole, _availableRoleIds);

  Map<String, dynamic> _roleInfo(String id) =>
      _roles.firstWhere((r) => r['id'] == id, orElse: () => _roles.first);

  // Display metadata for every profile role; ProfileRoles decides which are offered.
  final List<Map<String, dynamic>> _roles = [
    {
      'id': 'citizen',
      'title': 'Citizen Reporter',
      'desc': 'Discover emergency alerts, report local incidents & request aid',
      'icon': Icons.person_pin_rounded,
      'color': Colors.blue,
    },
    {
      'id': 'volunteer',
      'title': 'Crisis Volunteer',
      'desc': 'Respond to local incidents & assist neighborhood teams',
      'icon': Icons.volunteer_activism_rounded,
      'color': AppColors.safeEmerald,
    },
    {
      'id': 'ngo',
      'title': 'NGO Coordinator',
      'desc': 'Deploy supply logistics, shelters & medical relief teams',
      'icon': Icons.corporate_fare_rounded,
      'color': Colors.purple,
    },
    {
      'id': 'police',
      'title': 'Police Department',
      'desc': 'Law enforcement, traffic control & perimeter security',
      'icon': Icons.local_police_rounded,
      'color': Colors.indigo,
    },
    {
      'id': 'fire',
      'title': 'Fire Department',
      'desc': 'Firefighting, heavy rescue & hazardous material control',
      'icon': Icons.local_fire_department_rounded,
      'color': AppColors.primaryEmergencyRed,
    },
    {
      'id': 'ambulance',
      'title': 'Ambulance / EMS',
      'desc': 'Emergency medical evacuation, paramedic triage & transit',
      'icon': Icons.medical_services_rounded,
      'color': AppColors.warmSignalAmber,
    },
  ];

  final List<Map<String, dynamic>> _capabilitiesList = [
    {'name': 'First Aid', 'icon': Icons.healing_rounded},
    {'name': 'Medical Assistance', 'icon': Icons.medication_rounded},
    {'name': 'Fire Safety', 'icon': Icons.fire_hydrant_alt_rounded},
    {'name': 'Traffic Support', 'icon': Icons.traffic_rounded},
    {'name': 'Search & Rescue', 'icon': Icons.saved_search_rounded},
    {'name': 'Transport', 'icon': Icons.directions_car_rounded},
    {'name': 'Shelter Assistance', 'icon': Icons.other_houses_rounded},
    {'name': 'Food & Water', 'icon': Icons.fastfood_rounded},
    {'name': 'Communication', 'icon': Icons.cell_tower_rounded},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _syncDraftToProvider() {
    ref.read(profileProvider.notifier).updateDraft(
          displayName: _nameController.text.trim().isEmpty ? 'Responder User' : _nameController.text.trim(),
          username: _usernameController.text.trim(),
          bio: _bioController.text.trim(),
          location: _locationController.text.trim(),
          emergencyRole: _effectiveRole,
          skills: _selectedCapabilities.toList(),
          responseRadiusKm: _responseRadiusKm,
          emergencyAlertsEnabled: _enableEmergencyNotifications,
          nearbyAlertsEnabled: _enableNearbyAlerts,
          criticalOverrideEnabled: _enableCriticalAlerts,
          availabilityEnabled: _defaultAvailableToRespond,
          highUrgencySoundEnabled: _enableHighUrgencySound,
        );
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    _syncDraftToProvider();
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    _syncDraftToProvider();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _completeProfile() async {
    HapticFeedback.mediumImpact();
    _syncDraftToProvider();

    final success = await ref.read(profileProvider.notifier).saveProfile();

    if (!mounted) return;

    if (success) {
      final name = _nameController.text.trim().isEmpty ? 'Responder User' : _nameController.text.trim();
      await ref.read(authProvider.notifier).finalizeProfileSetup(
            fullName: name,
            role: _effectiveRole,
          );
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.status != AuthStatus.authenticated && authState.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.errorMessage!),
            backgroundColor: AppColors.primaryEmergencyRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final errorMsg = ref.read(profileProvider).errorMessage ?? 'Unable to save profile. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.primaryEmergencyRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profileState = ref.watch(profileProvider);
    final isSaving = profileState.status == ProfileStatus.saving;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (authState.status == AuthStatus.loading) {
      return const Scaffold(
        body: Center(
          child: LoadingWidget(message: 'Initializing your ResQConnect Profile...'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup ResQConnect Profile'),
        elevation: 0,
        centerTitle: true,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: isSaving ? null : _previousStep,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar (Responsive Flex Layout)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceM,
                vertical: AppTheme.spaceS,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'STEP ${_currentStep + 1} OF $_totalSteps',
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: AppColors.primaryEmergencyRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${(((_currentStep + 1) / _totalSteps) * 100).toInt()}% COMPLETE',
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      minHeight: 6,
                      backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryEmergencyRed),
                    ),
                  ),
                ],
              ),
            ),

            // Main Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                children: [
                  _buildStep1Identity(theme, isDark),
                  _buildStep2Role(theme, isDark),
                  _buildStep3Skills(theme, isDark),
                  _buildStep4ServiceArea(theme, isDark),
                  _buildStep5Preferences(theme, isDark),
                  _buildStep6Completion(theme, isDark),
                ],
              ),
            ),

            // Bottom Navigation CTA (Responsive constraints & text overflow protection)
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceM),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : (_currentStep == _totalSteps - 1 ? _completeProfile : _nextStep),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmergencyRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    elevation: 2,
                  ),
                  child: isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'SAVING PROFILE...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _currentStep == _totalSteps - 1 ? 'ENTER RESQCONNECT' : 'CONTINUE',
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.buttonText.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentStep == _totalSteps - 1
                                  ? Icons.check_circle_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SCREEN 1: PROFILE IDENTITY
  Widget _buildStep1Identity(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Identity',
            style: AppTheme.headlineMedium.copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your emergency profile so responders can verify your identity.',
            style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spaceL),

          // Avatar Picker
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryEmergencyRed, AppColors.deepEmergencyRed],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryEmergencyRed.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.person_rounded, size: 54, color: Colors.white),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryEmergencyRed, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 18, color: AppColors.primaryEmergencyRed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceL),

          // Name Input
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              hintText: 'John Doe',
              prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryEmergencyRed),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
            ),
          ),
          const SizedBox(height: AppTheme.spaceM),

          // Username Input
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: '@responder_john',
              prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppColors.primaryEmergencyRed),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
            ),
          ),
          const SizedBox(height: AppTheme.spaceM),

          // Short Bio Input
          TextField(
            controller: _bioController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Short Bio',
              hintText: 'Certified First Responder & neighborhood emergency contact',
              prefixIcon: const Icon(Icons.description_outlined, color: AppColors.primaryEmergencyRed),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
            ),
          ),
          const SizedBox(height: AppTheme.spaceM),

          // Location Input
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Primary Location',
              hintText: 'City, Sector or District',
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primaryEmergencyRed),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
            ),
          ),
        ],
      ),
    );
  }

  // SCREEN 2: EMERGENCY ROLE
  Widget _buildStep2Role(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Emergency Role',
            style: AppTheme.headlineMedium.copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your primary response designation in emergency events.',
            style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spaceM),

          ..._roles.where((role) => _availableRoleIds.contains(role['id'])).map((role) {
            final isSelected = _effectiveRole == role['id'];
            final roleColor = role['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spaceS),
              decoration: BoxDecoration(
                color: isSelected
                    ? roleColor.withValues(alpha: isDark ? 0.2 : 0.1)
                    : (isDark ? AppColors.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: isSelected ? roleColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedRole = role['id'] as String;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceM),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(role['icon'] as IconData, color: roleColor, size: 24),
                      ),
                      const SizedBox(width: AppTheme.spaceM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role['title'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? roleColor : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              role['desc'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? roleColor : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? roleColor : theme.colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // SCREEN 3: SKILLS & CAPABILITIES
  Widget _buildStep3Skills(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capabilities & Skills',
            style: AppTheme.headlineMedium.copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Select skills you can offer during active incident responses.',
            style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spaceM),

          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _capabilitiesList.map((item) {
              final name = item['name'] as String;
              final icon = item['icon'] as IconData;
              final isSelected = _selectedCapabilities.contains(name);

              return FilterChip(
                selected: isSelected,
                avatar: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : AppColors.primaryEmergencyRed,
                ),
                label: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                ),
                labelStyle: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontSize: 13,
                ),
                selectedColor: AppColors.primaryEmergencyRed,
                backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
                side: BorderSide(
                  color: isSelected ? AppColors.primaryEmergencyRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                onSelected: (selected) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (selected) {
                      _selectedCapabilities.add(name);
                    } else {
                      _selectedCapabilities.remove(name);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // SCREEN 4: SERVICE AREA
  Widget _buildStep4ServiceArea(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Define Response Area',
            style: AppTheme.headlineMedium.copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Set your coverage radius to get alerts for incidents happening nearby.',
            style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spaceL),

          // Map Visual Card
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.darkCard, AppColors.darkSurface]
                    : [Colors.blue.shade50, Colors.red.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.map_rounded,
                  size: 90,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryEmergencyRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black87 : Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Text(
                        'Coverage Radius: ${_responseRadiusKm.toInt()} km',
                        style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceL),

          Text(
            'Response Radius',
            style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _responseRadiusKm,
            min: 1.0,
            max: 50.0,
            divisions: 49,
            activeColor: AppColors.primaryEmergencyRed,
            label: '${_responseRadiusKm.toInt()} km',
            onChanged: (val) {
              setState(() {
                _responseRadiusKm = val;
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '1 km (Local)',
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '50 km (Regional)',
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // SCREEN 5: EMERGENCY PREFERENCES
  Widget _buildStep5Preferences(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency Preferences',
            style: AppTheme.headlineMedium.copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure how and when you receive urgent notifications.',
            style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spaceM),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Emergency Push Notifications'),
            subtitle: const Text('Receive instant push alerts for nearby incidents'),
            activeTrackColor: AppColors.primaryEmergencyRed,
            value: _enableEmergencyNotifications,
            onChanged: (val) => setState(() => _enableEmergencyNotifications = val),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nearby Incident Alerts'),
            subtitle: const Text('Alert when emergencies happen within your radius'),
            activeTrackColor: AppColors.primaryEmergencyRed,
            value: _enableNearbyAlerts,
            onChanged: (val) => setState(() => _enableNearbyAlerts = val),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Critical Override Alerts'),
            subtitle: const Text('Sound loud alert tones for high-severity life risks'),
            activeTrackColor: AppColors.primaryEmergencyRed,
            value: _enableCriticalAlerts,
            onChanged: (val) => setState(() => _enableCriticalAlerts = val),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default Available to Respond'),
            subtitle: const Text('Mark your status as Available when opening app'),
            activeTrackColor: AppColors.safeEmerald,
            value: _defaultAvailableToRespond,
            onChanged: (val) => setState(() => _defaultAvailableToRespond = val),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('High Urgency Sound & Vibration'),
            subtitle: const Text('Haptic pulse and distinct emergency chime'),
            activeTrackColor: AppColors.warmSignalAmber,
            value: _enableHighUrgencySound,
            onChanged: (val) => setState(() => _enableHighUrgencySound = val),
          ),
        ],
      ),
    );
  }

  // SCREEN 6: PROFILE COMPLETION
  Widget _buildStep6Completion(ThemeData theme, bool isDark) {
    final roleObj = _roleInfo(_effectiveRole);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppTheme.spaceS),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.safeEmerald.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              size: 52,
              color: AppColors.safeEmerald,
            ),
          ),
          const SizedBox(height: AppTheme.spaceS),

          Text(
            "You're Ready to Respond!",
            textAlign: TextAlign.center,
            style: AppTheme.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your emergency profile is 100% verified and initialized.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spaceM),

          // Summary Card (Responsive layout constraints & no overflow)
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceM),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryEmergencyRed,
                      child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: AppTheme.spaceM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.trim().isEmpty ? 'Responder User' : _nameController.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.titleLarge.copyWith(fontSize: 18),
                          ),
                          Text(
                            _usernameController.text.trim().isEmpty
                                ? '@responder_user'
                                : _usernameController.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodySmall.copyWith(color: AppColors.primaryEmergencyRed),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Selected Role
                Row(
                  children: [
                    Icon(roleObj['icon'] as IconData, color: roleObj['color'] as Color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Role: ', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                            TextSpan(text: roleObj['title'] as String, style: AppTheme.bodyMedium),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Selected Radius
                Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: AppColors.warmSignalAmber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Response Radius: ', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                            TextSpan(text: '${_responseRadiusKm.toInt()} km coverage', style: AppTheme.bodyMedium),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Capabilities Count
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.purple, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Capabilities: ', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                            TextSpan(text: '${_selectedCapabilities.length} skills selected', style: AppTheme.bodyMedium),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
