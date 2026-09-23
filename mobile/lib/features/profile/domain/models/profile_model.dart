class ProfileModel {
  final String id;
  final String userId;
  final String displayName;
  final String username;
  final String bio;
  final String avatarUrl;
  final String location;
  final String emergencyRole;
  final List<String> skills;
  final double responseRadiusKm;
  final bool emergencyAlertsEnabled;
  final bool nearbyAlertsEnabled;
  final bool criticalOverrideEnabled;
  final bool availabilityEnabled;
  final bool highUrgencySoundEnabled;
  final bool profileCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.avatarUrl,
    required this.location,
    required this.emergencyRole,
    required this.skills,
    required this.responseRadiusKm,
    required this.emergencyAlertsEnabled,
    required this.nearbyAlertsEnabled,
    required this.criticalOverrideEnabled,
    required this.availabilityEnabled,
    required this.highUrgencySoundEnabled,
    required this.profileCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.initial() {
    return ProfileModel(
      id: 'dev-profile-001',
      userId: 'dev-user-001',
      displayName: 'Responder User',
      username: 'responder_user',
      bio: 'Certified First Responder & neighborhood emergency contact',
      avatarUrl: '',
      location: 'Sector 4, Metro Valley',
      emergencyRole: 'citizen',
      skills: const ['First Aid', 'Communication'],
      responseRadiusKm: 10.0,
      emergencyAlertsEnabled: true,
      nearbyAlertsEnabled: true,
      criticalOverrideEnabled: true,
      availabilityEnabled: true,
      highUrgencySoundEnabled: true,
      profileCompleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  ProfileModel copyWith({
    String? id,
    String? userId,
    String? displayName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? location,
    String? emergencyRole,
    List<String>? skills,
    double? responseRadiusKm,
    bool? emergencyAlertsEnabled,
    bool? nearbyAlertsEnabled,
    bool? criticalOverrideEnabled,
    bool? availabilityEnabled,
    bool? highUrgencySoundEnabled,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      location: location ?? this.location,
      emergencyRole: emergencyRole ?? this.emergencyRole,
      skills: skills ?? this.skills,
      responseRadiusKm: responseRadiusKm ?? this.responseRadiusKm,
      emergencyAlertsEnabled: emergencyAlertsEnabled ?? this.emergencyAlertsEnabled,
      nearbyAlertsEnabled: nearbyAlertsEnabled ?? this.nearbyAlertsEnabled,
      criticalOverrideEnabled: criticalOverrideEnabled ?? this.criticalOverrideEnabled,
      availabilityEnabled: availabilityEnabled ?? this.availabilityEnabled,
      highUrgencySoundEnabled: highUrgencySoundEnabled ?? this.highUrgencySoundEnabled,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['full_name'] as String? ?? 'Responder User',
      username: json['username'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? json['profile_photo'] as String? ?? '',
      location: json['location'] as String? ?? '',
      emergencyRole: json['emergency_role'] as String? ?? json['role'] as String? ?? 'citizen',
      skills: (json['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      responseRadiusKm: (json['response_radius_km'] as num?)?.toDouble() ?? 10.0,
      emergencyAlertsEnabled: json['emergency_alerts_enabled'] as bool? ?? true,
      nearbyAlertsEnabled: json['nearby_alerts_enabled'] as bool? ?? true,
      criticalOverrideEnabled: json['critical_override_enabled'] as bool? ?? true,
      availabilityEnabled: json['availability_enabled'] as bool? ?? true,
      highUrgencySoundEnabled: json['high_urgency_sound_enabled'] as bool? ?? true,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      if (username.isNotEmpty) 'username': username,
      if (bio.isNotEmpty) 'bio': bio,
      if (avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
      if (location.isNotEmpty) 'location': location,
      'emergency_role': emergencyRole,
      'skills': skills,
      'response_radius_km': responseRadiusKm,
      'emergency_alerts_enabled': emergencyAlertsEnabled,
      'nearby_alerts_enabled': nearbyAlertsEnabled,
      'critical_override_enabled': criticalOverrideEnabled,
      'availability_enabled': availabilityEnabled,
      'high_urgency_sound_enabled': highUrgencySoundEnabled,
    };
  }
}
