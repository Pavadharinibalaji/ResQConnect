class IncidentResponderModel {
  final String id;
  final String incidentId;
  final String userId;
  final String status; // responding, arrived, assisting, completed, withdrawn
  final DateTime joinedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? notes;
  final String? userName;
  final String? userRole;
  final String? userPhoto;
  final String? emergencyRole;

  const IncidentResponderModel({
    required this.id,
    required this.incidentId,
    required this.userId,
    required this.status,
    required this.joinedAt,
    required this.updatedAt,
    this.completedAt,
    this.notes,
    this.userName,
    this.userRole,
    this.userPhoto,
    this.emergencyRole,
  });

  factory IncidentResponderModel.fromJson(Map<String, dynamic> json) {
    final userObj = json['user'] as Map<String, dynamic>?;
    return IncidentResponderModel(
      id: json['id'] as String? ?? '',
      incidentId: json['incident_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      status: json['status'] as String? ?? 'responding',
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      notes: json['notes'] as String?,
      userName: userObj?['full_name'] as String?,
      userRole: userObj?['role'] as String?,
      userPhoto: userObj?['profile_photo'] as String?,
      emergencyRole: userObj?['emergency_role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_id': incidentId,
      'user_id': userId,
      'status': status,
      'joined_at': joinedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
      'user': {
        'full_name': userName,
        'role': userRole,
        'profile_photo': userPhoto,
        'emergency_role': emergencyRole,
      },
    };
  }

  IncidentResponderModel copyWith({
    String? id,
    String? incidentId,
    String? userId,
    String? status,
    DateTime? joinedAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? notes,
    String? userName,
    String? userRole,
    String? userPhoto,
    String? emergencyRole,
  }) {
    return IncidentResponderModel(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      userPhoto: userPhoto ?? this.userPhoto,
      emergencyRole: emergencyRole ?? this.emergencyRole,
    );
  }
}
