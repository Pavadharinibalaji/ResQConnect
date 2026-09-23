import 'package:resqconnect/features/feed/domain/models/evidence_model.dart';
import 'package:resqconnect/features/feed/domain/models/responder_model.dart';

class IncidentModel {
  final String id;
  final String? reporterId;
  final String? assignedResponderId;
  final String title;
  final String description;
  final String category;
  final String severity;
  final String status;
  final double latitude;
  final double longitude;
  final String address;
  final double? distanceKm;
  final int responderCount;
  final String? userResponderStatus; // responding, arrived, assisting, completed, withdrawn
  final List<IncidentResponderModel> responders;
  final List<IncidentEvidenceModel> evidence;
  final bool isVerified;
  final String reporterName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncidentModel({
    required this.id,
    this.reporterId,
    this.assignedResponderId,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.distanceKm,
    this.responderCount = 0,
    this.userResponderStatus,
    this.responders = const [],
    this.evidence = const [],
    this.isVerified = true,
    this.reporterName = 'Civic Reporter',
    required this.createdAt,
    required this.updatedAt,
  });

  factory IncidentModel.initial() {
    return IncidentModel(
      id: 'inc-${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      description: '',
      category: 'fire',
      severity: 'critical',
      status: 'reported',
      latitude: 12.9716,
      longitude: 77.5946,
      address: 'Sector 4, Urban Valley',
      distanceKm: 1.2,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  bool get isUserResponding =>
      userResponderStatus != null && userResponderStatus != 'withdrawn';

  IncidentModel copyWith({
    String? id,
    String? reporterId,
    String? assignedResponderId,
    String? title,
    String? description,
    String? category,
    String? severity,
    String? status,
    double? latitude,
    double? longitude,
    String? address,
    double? distanceKm,
    int? responderCount,
    String? userResponderStatus,
    bool clearUserResponderStatus = false,
    List<IncidentResponderModel>? responders,
    List<IncidentEvidenceModel>? evidence,
    bool? isVerified,
    String? reporterName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return IncidentModel(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      assignedResponderId: assignedResponderId ?? this.assignedResponderId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      distanceKm: distanceKm ?? this.distanceKm,
      responderCount: responderCount ?? this.responderCount,
      userResponderStatus: clearUserResponderStatus ? null : (userResponderStatus ?? this.userResponderStatus),
      responders: responders ?? this.responders,
      evidence: evidence ?? this.evidence,
      isVerified: isVerified ?? this.isVerified,
      reporterName: reporterName ?? this.reporterName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    final respondersRaw = json['responders'] as List<dynamic>?;
    final respondersList = respondersRaw != null
        ? respondersRaw.map((e) => IncidentResponderModel.fromJson(e as Map<String, dynamic>)).toList()
        : <IncidentResponderModel>[];

    final evidenceRaw = json['evidence'] as List<dynamic>?;
    final evidenceList = evidenceRaw != null
        ? evidenceRaw.map((e) => IncidentEvidenceModel.fromJson(e as Map<String, dynamic>)).toList()
        : <IncidentEvidenceModel>[];

    return IncidentModel(
      id: json['id'] as String? ?? 'inc-${DateTime.now().millisecondsSinceEpoch}',
      reporterId: json['reporter_id'] as String?,
      assignedResponderId: json['assigned_responder_id'] as String?,
      title: json['title'] as String? ?? 'Emergency Incident',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'medical',
      severity: json['severity'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'reported',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 12.9716,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 77.5946,
      address: json['address'] as String? ?? 'Nearby Location',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? (json['distanceKm'] as num?)?.toDouble(),
      responderCount: json['responder_count'] as int? ?? (json['responderCount'] as int? ?? 0),
      userResponderStatus: json['user_responder_status'] as String? ?? json['userResponderStatus'] as String?,
      responders: respondersList,
      evidence: evidenceList,
      isVerified: json['isVerified'] as bool? ?? (json['is_verified'] as bool? ?? true),
      reporterName: json['reporterName'] as String? ?? (json['reporter_name'] as String? ?? 'Civic Reporter'),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      if (address.isNotEmpty) 'address': address,
      if (distanceKm != null) 'distance_km': distanceKm,
    };
  }

  Map<String, dynamic> toCardJson() {
    final now = DateTime.now();
    final diff = now.difference(createdAt).inMinutes;
    final timeAgoStr = diff <= 1 ? 'Just now' : '${diff}m ago';
    final distanceStr = distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km away' : '1.2 km away';

    return {
      'id': id,
      'title': title,
      'category': category,
      'severity': severity,
      'location': address,
      'distance': distanceStr,
      'time': timeAgoStr,
      'description': description,
      'responderCount': responderCount,
      'userResponderStatus': userResponderStatus,
      'isUserResponding': isUserResponding,
      'isVerified': isVerified,
      'reporterName': reporterName,
      'status': status,
    };
  }
}
