import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:resqconnect/config/env.dart';
import 'package:resqconnect/core/errors/api_error_parser.dart';
import 'package:resqconnect/core/errors/failures.dart';
import 'package:resqconnect/core/logger/app_logger.dart';
import 'package:resqconnect/core/storage/secure_storage.dart';
import 'package:resqconnect/features/feed/domain/models/evidence_model.dart';
import 'package:resqconnect/features/feed/domain/models/incident_model.dart';
import 'package:resqconnect/features/feed/domain/models/responder_model.dart';
import 'package:resqconnect/features/feed/domain/repositories/incident_repository.dart';

class IncidentRepositoryImpl implements IncidentRepository {
  final Dio _dio;
  final SecureStorage _secureStorage;

  IncidentRepositoryImpl(this._dio, this._secureStorage);

  static const String _storageKeyIncidents = 'key_incidents_feed_cache';
  final List<IncidentModel> _inMemoryIncidents = [];

  @override
  Future<IncidentModel> createIncident(IncidentModel draft) async {
    final created = draft.copyWith(
      id: 'inc-${DateTime.now().millisecondsSinceEpoch}',
      status: 'reported',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _inMemoryIncidents.insert(0, created);
    await _cacheIncidents();

    if (Env.isDevAuthBypassEnabled) {
      debugPrint('[DEBUG_INCIDENT] Incident created locally in DEV mode: ${created.title}');
      try {
        final response = await _dio.post(
          '${Env.apiBaseUrl}/api/v1/incidents',
          data: created.toJson(),
        );
        if (response.statusCode == 201) {
          final remoteData = response.data['data'] as Map<String, dynamic>;
          final remoteIncident = IncidentModel.fromJson(remoteData);
          debugPrint('[DEBUG_INCIDENT] Remote incident synced: ${remoteIncident.id}');
          return remoteIncident;
        }
      } catch (e) {
        debugPrint('[DEBUG_INCIDENT] Remote POST skipped in DEV mode (LAN unreachable): $e');
      }
      return created;
    }

    try {
      final response = await _dio.post(
        '${Env.apiBaseUrl}/api/v1/incidents',
        data: created.toJson(),
      );
      final remoteData = response.data['data'] as Map<String, dynamic>;
      return IncidentModel.fromJson(remoteData);
    } on DioException catch (e) {
      AppLogger.error('Backend POST /api/v1/incidents failed', error: e);
      throw _handleDioError(e);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<IncidentModel>> getIncidents({String? category, String? severity, String? status}) async {
    try {
      final response = await _dio.get(
        '${Env.apiBaseUrl}/api/v1/incidents',
        queryParameters: {
          if (category != null) 'category': category,
          if (severity != null) 'severity': severity,
          if (status != null) 'status': status,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final list = data['incidents'] as List<dynamic>;
      final remoteIncidents = list.map((e) => IncidentModel.fromJson(e as Map<String, dynamic>)).toList();

      final combined = [..._inMemoryIncidents, ...remoteIncidents];
      final uniqueMap = <String, IncidentModel>{};
      for (final item in combined) {
        uniqueMap[item.id] = item;
      }
      return uniqueMap.values.toList();
    } on DioException catch (e) {
      AppLogger.warning('Backend GET /api/v1/incidents failed: ${e.message}');
      if (Env.isDevAuthBypassEnabled || _inMemoryIncidents.isNotEmpty) {
        final cached = await _loadCachedIncidents();
        final combined = [..._inMemoryIncidents, ...cached];
        final uniqueMap = <String, IncidentModel>{};
        for (final item in combined) {
          uniqueMap[item.id] = item;
        }
        return uniqueMap.values.toList();
      }
      throw _handleDioError(e);
    } catch (e) {
      if (_inMemoryIncidents.isNotEmpty) {
        return _inMemoryIncidents;
      }
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<IncidentModel>> getNearbyIncidents({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
    String? category,
    String? severity,
    String? status,
  }) async {
    try {
      final response = await _dio.get(
        '${Env.apiBaseUrl}/api/v1/incidents/nearby',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'radius_km': radiusKm,
          if (category != null) 'category': category,
          if (severity != null) 'severity': severity,
          if (status != null) 'status': status,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final list = data['incidents'] as List<dynamic>;
      final remoteIncidents = list.map((e) => IncidentModel.fromJson(e as Map<String, dynamic>)).toList();

      final combined = [..._inMemoryIncidents, ...remoteIncidents];
      final uniqueMap = <String, IncidentModel>{};
      for (final item in combined) {
        uniqueMap[item.id] = item;
      }
      return uniqueMap.values.toList();
    } on DioException catch (e) {
      AppLogger.warning('Backend GET /api/v1/incidents/nearby failed: ${e.message}');
      if (Env.isDevAuthBypassEnabled || _inMemoryIncidents.isNotEmpty) {
        final all = await getIncidents(category: category, severity: severity, status: status);
        return all;
      }
      throw _handleDioError(e);
    } catch (e) {
      return getIncidents(category: category, severity: severity, status: status);
    }
  }

  @override
  Future<IncidentModel> getIncidentDetail(String incidentId) async {
    final localMatch = _inMemoryIncidents.firstWhere(
      (item) => item.id == incidentId,
      orElse: () => IncidentModel.initial().copyWith(id: incidentId),
    );

    try {
      final response = await _dio.get('${Env.apiBaseUrl}/api/v1/incidents/$incidentId');
      final data = response.data['data'] as Map<String, dynamic>;
      return IncidentModel.fromJson(data);
    } catch (e) {
      if (Env.isDevAuthBypassEnabled || localMatch.title.isNotEmpty) {
        return localMatch;
      }
      throw ServerFailure('Unable to load incident details: $e');
    }
  }

  @override
  Future<IncidentModel> updateIncidentStatus(String incidentId, String status) async {
    try {
      final response = await _dio.patch(
        '${Env.apiBaseUrl}/api/v1/incidents/$incidentId/status',
        data: {'status': status},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return IncidentModel.fromJson(data);
    } catch (e) {
      final index = _inMemoryIncidents.indexWhere((item) => item.id == incidentId);
      if (index != -1) {
        _inMemoryIncidents[index] = _inMemoryIncidents[index].copyWith(status: status);
        return _inMemoryIncidents[index];
      }
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<IncidentModel> respondToIncident(String incidentId, {String? notes}) async {
    try {
      final response = await _dio.post(
        '${Env.apiBaseUrl}/api/v1/incidents/$incidentId/respond',
        data: notes != null ? {'notes': notes} : null,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return IncidentModel.fromJson(data);
    } catch (e) {
      final index = _inMemoryIncidents.indexWhere((item) => item.id == incidentId);
      if (index != -1) {
        final updatedCount = _inMemoryIncidents[index].responderCount + 1;
        _inMemoryIncidents[index] = _inMemoryIncidents[index].copyWith(
          userResponderStatus: 'responding',
          responderCount: updatedCount,
          status: 'active',
        );
        return _inMemoryIncidents[index];
      }
      if (e is DioException) throw _handleDioError(e);
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<IncidentModel> withdrawResponse(String incidentId) async {
    try {
      final response = await _dio.delete(
        '${Env.apiBaseUrl}/api/v1/incidents/$incidentId/respond',
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return IncidentModel.fromJson(data);
    } catch (e) {
      final index = _inMemoryIncidents.indexWhere((item) => item.id == incidentId);
      if (index != -1) {
        final updatedCount = (_inMemoryIncidents[index].responderCount - 1).clamp(0, 999);
        _inMemoryIncidents[index] = _inMemoryIncidents[index].copyWith(
          userResponderStatus: 'withdrawn',
          responderCount: updatedCount,
        );
        return _inMemoryIncidents[index];
      }
      if (e is DioException) throw _handleDioError(e);
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<IncidentModel> updateMyResponderStatus(String incidentId, String status, {String? notes}) async {
    try {
      final response = await _dio.patch(
        '${Env.apiBaseUrl}/api/v1/incidents/$incidentId/responders/me/status',
        data: {'status': status, if (notes != null) 'notes': notes},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return IncidentModel.fromJson(data);
    } catch (e) {
      final index = _inMemoryIncidents.indexWhere((item) => item.id == incidentId);
      if (index != -1) {
        _inMemoryIncidents[index] = _inMemoryIncidents[index].copyWith(
          userResponderStatus: status,
        );
        return _inMemoryIncidents[index];
      }
      if (e is DioException) throw _handleDioError(e);
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<List<IncidentResponderModel>> getIncidentResponders(String incidentId) async {
    try {
      final response = await _dio.get('${Env.apiBaseUrl}/api/v1/incidents/$incidentId/responders');
      final list = response.data['data'] as List<dynamic>;
      return list.map((e) => IncidentResponderModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<IncidentResponderModel?> getMyResponderStatus(String incidentId) async {
    try {
      final response = await _dio.get('${Env.apiBaseUrl}/api/v1/incidents/$incidentId/responders/me');
      final data = response.data['data'];
      if (data != null) {
        return IncidentResponderModel.fromJson(data as Map<String, dynamic>);
      }
    } catch (e) {
      // Return null if not responding
    }
    return null;
  }

  @override
  Future<IncidentEvidenceModel> uploadEvidence(String incidentId, String filePath, String type) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post(
        '${Env.apiBaseUrl}/api/v1/incidents/$incidentId/evidence?type=$type',
        data: formData,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return IncidentEvidenceModel.fromJson(data);
    } on DioException catch (e) {
      // Surface the failure: returning a local placeholder made failed uploads look successful.
      AppLogger.error('Evidence upload failed (status ${e.response?.statusCode})', error: e.type.name);
      throw ApiErrorParser.fromDioException(e, fallbackMessage: 'The evidence file could not be uploaded.');
    } catch (e) {
      AppLogger.error('Evidence upload failed', error: e);
      throw ApiErrorParser.fromError(e, fallbackMessage: 'The evidence file could not be read or uploaded.');
    }
  }

  Future<void> _cacheIncidents() async {
    try {
      final jsonList = _inMemoryIncidents.map((e) => e.toJson()).toList();
      await _secureStorage.write(_storageKeyIncidents, jsonEncode(jsonList));
    } catch (e) {
      AppLogger.warning('Failed to cache incidents: $e');
    }
  }

  Future<List<IncidentModel>> _loadCachedIncidents() async {
    try {
      final jsonStr = await _secureStorage.read(_storageKeyIncidents);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list.map((e) => IncidentModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      AppLogger.warning('Failed to read cached incidents: $e');
    }
    return [];
  }

  Failure _handleDioError(DioException e) =>
      ApiErrorParser.fromDioException(e, fallbackMessage: 'Incident request failed.');
}
