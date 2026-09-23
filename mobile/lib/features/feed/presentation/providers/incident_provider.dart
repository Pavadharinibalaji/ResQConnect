import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqconnect/core/logger/app_logger.dart';
import 'package:resqconnect/features/feed/data/evidence_media_loader.dart';
import 'package:resqconnect/features/feed/data/repositories/incident_repository_impl.dart';
import 'package:resqconnect/features/feed/domain/models/incident_model.dart';
import 'package:resqconnect/features/feed/domain/repositories/incident_repository.dart';
import 'package:resqconnect/shared/providers/global_providers.dart';

enum IncidentStatus { initial, loading, creating, created, loaded, error }

class IncidentState {
  final IncidentStatus status;
  final List<IncidentModel> incidents;
  final IncidentModel? currentIncident;
  final IncidentModel draft;
  final double selectedRadiusKm;
  final String? errorMessage;

  const IncidentState({
    required this.status,
    required this.incidents,
    this.currentIncident,
    required this.draft,
    this.selectedRadiusKm = 5.0,
    this.errorMessage,
  });

  factory IncidentState.initial() => IncidentState(
        status: IncidentStatus.initial,
        incidents: const [],
        draft: IncidentModel.initial(),
        selectedRadiusKm: 5.0,
      );

  IncidentState copyWith({
    IncidentStatus? status,
    List<IncidentModel>? incidents,
    IncidentModel? currentIncident,
    IncidentModel? draft,
    double? selectedRadiusKm,
    String? errorMessage,
    bool clearError = false,
  }) {
    return IncidentState(
      status: status ?? this.status,
      incidents: incidents ?? this.incidents,
      currentIncident: currentIncident ?? this.currentIncident,
      draft: draft ?? this.draft,
      selectedRadiusKm: selectedRadiusKm ?? this.selectedRadiusKm,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class IncidentNotifier extends StateNotifier<IncidentState> {
  final IncidentRepository _repository;

  IncidentNotifier(this._repository) : super(IncidentState.initial()) {
    fetchIncidents();
  }

  Future<void> fetchIncidents({String? category, String? severity}) async {
    state = state.copyWith(status: IncidentStatus.loading, clearError: true);
    try {
      final list = await _repository.getIncidents(category: category, severity: severity);
      state = state.copyWith(status: IncidentStatus.loaded, incidents: list);
      AppLogger.info('Retrieved ${list.length} incidents for emergency feed');
    } catch (e) {
      AppLogger.warning('Failed to fetch incidents: $e');
      state = state.copyWith(status: IncidentStatus.loaded);
    }
  }

  Future<void> fetchNearbyIncidents({
    required double latitude,
    required double longitude,
    double? radiusKm,
    String? category,
    String? severity,
  }) async {
    final effectiveRadius = radiusKm ?? state.selectedRadiusKm;
    state = state.copyWith(status: IncidentStatus.loading, selectedRadiusKm: effectiveRadius, clearError: true);
    try {
      final list = await _repository.getNearbyIncidents(
        latitude: latitude,
        longitude: longitude,
        radiusKm: effectiveRadius,
        category: category,
        severity: severity,
      );
      state = state.copyWith(status: IncidentStatus.loaded, incidents: list);
      AppLogger.info('Retrieved ${list.length} nearby incidents within ${effectiveRadius}km');
    } catch (e) {
      AppLogger.warning('Failed to fetch nearby incidents: $e');
      state = state.copyWith(status: IncidentStatus.loaded);
    }
  }

  void setSelectedRadius(double radiusKm) {
    state = state.copyWith(selectedRadiusKm: radiusKm);
  }

  Future<void> fetchIncidentDetail(String id) async {
    state = state.copyWith(status: IncidentStatus.loading, clearError: true);
    try {
      final detail = await _repository.getIncidentDetail(id);
      state = state.copyWith(status: IncidentStatus.loaded, currentIncident: detail);
    } catch (e) {
      AppLogger.error('Failed to fetch incident detail', error: e);
      state = state.copyWith(status: IncidentStatus.error, errorMessage: e.toString());
    }
  }

  void updateDraft({
    String? title,
    String? description,
    String? category,
    String? severity,
    double? latitude,
    double? longitude,
    String? address,
  }) {
    final updated = state.draft.copyWith(
      title: title,
      description: description,
      category: category,
      severity: severity,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    state = state.copyWith(draft: updated, clearError: true);
  }

  void resetDraft() {
    state = state.copyWith(draft: IncidentModel.initial());
  }

  Future<IncidentModel?> createIncident() async {
    final draft = state.draft;

    if (draft.title.trim().isEmpty) {
      state = state.copyWith(
        status: IncidentStatus.error,
        errorMessage: 'Please enter a title or summary for the emergency.',
      );
      return null;
    }

    if (draft.description.trim().isEmpty) {
      state = state.copyWith(
        status: IncidentStatus.error,
        errorMessage: 'Please enter a description for the emergency.',
      );
      return null;
    }

    state = state.copyWith(status: IncidentStatus.creating, clearError: true);
    debugPrint('[DEBUG_INCIDENT] Submitting emergency report: ${draft.title}');

    try {
      final created = await _repository.createIncident(draft);
      final updatedList = [created, ...state.incidents];
      state = state.copyWith(
        status: IncidentStatus.created,
        incidents: updatedList,
        currentIncident: created,
        draft: IncidentModel.initial(),
      );
      debugPrint('[DEBUG_INCIDENT] Emergency reported successfully: ${created.id}');
      return created;
    } catch (e) {
      AppLogger.error('Error creating incident', error: e);
      state = state.copyWith(
        status: IncidentStatus.error,
        errorMessage: 'Unable to report emergency right now. ${e.toString().replaceAll('Exception: ', '')}',
      );
      return null;
    }
  }

  Future<bool> respondToIncident(String incidentId, {String? notes}) async {
    state = state.copyWith(status: IncidentStatus.loading, clearError: true);
    try {
      try { await HapticFeedback.mediumImpact(); } catch (_) {}
      final updatedIncident = await _repository.respondToIncident(incidentId, notes: notes);

      final updatedList = state.incidents.map((item) {
        return item.id == incidentId ? updatedIncident : item;
      }).toList();

      state = state.copyWith(
        status: IncidentStatus.loaded,
        incidents: updatedList,
        currentIncident: updatedIncident,
      );
      AppLogger.info('Successfully joined emergency response for incident $incidentId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to respond to incident', error: e);
      state = state.copyWith(
        status: IncidentStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> updateResponderStatus(String incidentId, String newStatus, {String? notes}) async {
    state = state.copyWith(status: IncidentStatus.loading, clearError: true);
    try {
      try { await HapticFeedback.selectionClick(); } catch (_) {}
      final updatedIncident = await _repository.updateMyResponderStatus(incidentId, newStatus, notes: notes);

      final updatedList = state.incidents.map((item) {
        return item.id == incidentId ? updatedIncident : item;
      }).toList();

      state = state.copyWith(
        status: IncidentStatus.loaded,
        incidents: updatedList,
        currentIncident: updatedIncident,
      );
      AppLogger.info('Updated responder status to $newStatus for incident $incidentId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update responder status', error: e);
      state = state.copyWith(
        status: IncidentStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> withdrawResponse(String incidentId) async {
    state = state.copyWith(status: IncidentStatus.loading, clearError: true);
    try {
      try { await HapticFeedback.lightImpact(); } catch (_) {}
      final updatedIncident = await _repository.withdrawResponse(incidentId);

      final updatedList = state.incidents.map((item) {
        return item.id == incidentId ? updatedIncident : item;
      }).toList();

      state = state.copyWith(
        status: IncidentStatus.loaded,
        incidents: updatedList,
        currentIncident: updatedIncident,
      );
      AppLogger.info('Withdrew response for incident $incidentId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to withdraw response', error: e);
      state = state.copyWith(
        status: IncidentStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> updateIncidentLifecycleStatus(String incidentId, String newStatus) async {
    state = state.copyWith(status: IncidentStatus.loading, clearError: true);
    try {
      try { await HapticFeedback.mediumImpact(); } catch (_) {}
      final updatedIncident = await _repository.updateIncidentStatus(incidentId, newStatus);

      final updatedList = state.incidents.map((item) {
        return item.id == incidentId ? updatedIncident : item;
      }).toList();

      state = state.copyWith(
        status: IncidentStatus.loaded,
        incidents: updatedList,
        currentIncident: updatedIncident,
      );
      AppLogger.info('Incident $incidentId status updated to $newStatus');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update incident lifecycle status', error: e);
      state = state.copyWith(
        status: IncidentStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

/// Loads protected evidence files through the authenticated API client.
final evidenceMediaLoaderProvider = Provider<EvidenceMediaLoader>((ref) {
  return EvidenceMediaLoader(ref.watch(dioClientProvider).instance);
});

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return IncidentRepositoryImpl(dioClient.instance, storage);
});

final incidentProvider = StateNotifierProvider<IncidentNotifier, IncidentState>((ref) {
  final repository = ref.watch(incidentRepositoryProvider);
  return IncidentNotifier(repository);
});
