import 'package:dio/dio.dart';

class IncidentRemoteDatasource {
  final Dio _dio;

  const IncidentRemoteDatasource(this._dio);

  Future<Map<String, dynamic>> fetchIncidents({
    String? category,
    String? status,
    String? severity,
  }) async {
    final queryParams = <String, dynamic>{};
    if (category != null) queryParams['category'] = category;
    if (status != null) queryParams['status'] = status;
    if (severity != null) queryParams['severity'] = severity;

    final response = await _dio.get(
      '/incidents',
      queryParameters: queryParams,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createIncident({
    required String title,
    required String description,
    required String category,
    required String severity,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final response = await _dio.post(
      '/incidents',
      data: {
        'title': title,
        'description': description,
        'category': category,
        'severity': severity,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
