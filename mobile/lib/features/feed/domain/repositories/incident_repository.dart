import 'package:resqconnect/features/feed/domain/models/evidence_model.dart';
import 'package:resqconnect/features/feed/domain/models/incident_model.dart';
import 'package:resqconnect/features/feed/domain/models/responder_model.dart';

abstract class IncidentRepository {
  Future<IncidentModel> createIncident(IncidentModel draft);
  Future<List<IncidentModel>> getIncidents({String? category, String? severity, String? status});
  Future<List<IncidentModel>> getNearbyIncidents({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    String? category,
    String? severity,
    String? status,
  });
  Future<IncidentModel> getIncidentDetail(String incidentId);
  Future<IncidentModel> updateIncidentStatus(String incidentId, String status);

  // Responder APIs
  Future<IncidentModel> respondToIncident(String incidentId, {String? notes});
  Future<IncidentModel> withdrawResponse(String incidentId);
  Future<IncidentModel> updateMyResponderStatus(String incidentId, String status, {String? notes});
  Future<List<IncidentResponderModel>> getIncidentResponders(String incidentId);
  Future<IncidentResponderModel?> getMyResponderStatus(String incidentId);

  // Evidence API
  Future<IncidentEvidenceModel> uploadEvidence(String incidentId, String filePath, String type);
}
