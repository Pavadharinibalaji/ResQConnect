class IncidentEvidenceModel {
  final String id;
  final String incidentId;
  final String type; // photo, video
  final String fileUrl;
  final DateTime? createdAt;

  const IncidentEvidenceModel({
    required this.id,
    required this.incidentId,
    required this.type,
    required this.fileUrl,
    this.createdAt,
  });

  factory IncidentEvidenceModel.fromJson(Map<String, dynamic> json) {
    return IncidentEvidenceModel(
      id: json['id'] as String? ?? '',
      incidentId: json['incident_id'] as String? ?? '',
      type: json['type'] as String? ?? 'photo',
      fileUrl: json['file_url'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_id': incidentId,
      'type': type,
      'file_url': fileUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
