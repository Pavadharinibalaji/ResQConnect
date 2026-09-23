import 'package:flutter/foundation.dart';

class UserModel {
  final String uid;
  final String firebaseUid;
  final String phoneNumber;
  final String? name;
  final String? email;
  final String? profilePhoto;
  final String role;

  /// Role names from the backend's `roles` list (`user_roles`): the roles an admin
  /// granted plus self-service roles the user selected. Display/UX only; the backend
  /// decides what a user may select.
  final List<String> grantedRoles;
  final bool isVerified;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.firebaseUid,
    required this.phoneNumber,
    this.name,
    this.email,
    this.profilePhoto,
    required this.role,
    this.grantedRoles = const [],
    required this.isVerified,
    required this.isActive,
    this.lastLogin,
    required this.createdAt,
  });

  UserModel copyWith({
    String? uid,
    String? firebaseUid,
    String? phoneNumber,
    String? name,
    String? email,
    String? profilePhoto,
    String? role,
    List<String>? grantedRoles,
    bool? isVerified,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      role: role ?? this.role,
      grantedRoles: grantedRoles ?? this.grantedRoles,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String? ?? json['id'] as String? ?? '',
      firebaseUid: json['firebase_uid'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      name: json['full_name'] as String? ?? json['name'] as String?,
      email: json['email'] as String?,
      profilePhoto: json['profile_photo'] as String?,
      role: json['role'] as String? ?? 'citizen',
      grantedRoles: _parseRoleNames(json['roles']),
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      lastLogin: json['last_login'] != null ? DateTime.parse(json['last_login'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
    );
  }

  /// Accepts `[{"name": "police", ...}]` or `["police"]`; ignores anything else.
  static List<String> _parseRoleNames(Object? raw) {
    if (raw is! List) return const [];
    final names = <String>[];
    for (final item in raw) {
      final name = item is Map ? item['name'] : item;
      if (name is String && name.trim().isNotEmpty) {
        names.add(name.trim().toLowerCase());
      }
    }
    return List.unmodifiable(names);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'firebase_uid': firebaseUid,
      'phone_number': phoneNumber,
      'full_name': name,
      if (email != null) 'email': email,
      if (profilePhoto != null) 'profile_photo': profilePhoto,
      'role': role,
      'roles': [for (final name in grantedRoles) {'name': name}],
      'is_verified': isVerified,
      'is_active': isActive,
      if (lastLogin != null) 'last_login': lastLogin!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          firebaseUid == other.firebaseUid &&
          phoneNumber == other.phoneNumber &&
          name == other.name &&
          email == other.email &&
          profilePhoto == other.profilePhoto &&
          role == other.role &&
          listEquals(grantedRoles, other.grantedRoles) &&
          isVerified == other.isVerified &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      uid.hashCode ^
      firebaseUid.hashCode ^
      phoneNumber.hashCode ^
      name.hashCode ^
      email.hashCode ^
      profilePhoto.hashCode ^
      role.hashCode ^
      Object.hashAll(grantedRoles) ^
      isVerified.hashCode ^
      isActive.hashCode;
}
