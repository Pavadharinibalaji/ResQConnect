import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:resqconnect/config/env.dart';

enum EvidenceLoadError { unauthorized, forbidden, notFound, network, invalidUrl, unavailable }

/// Why an evidence file could not be shown, with a user-facing message.
class EvidenceLoadFailure implements Exception {
  final EvidenceLoadError reason;

  const EvidenceLoadFailure(this.reason);

  factory EvidenceLoadFailure.fromDioException(DioException error) {
    switch (error.response?.statusCode) {
      case 401:
        return const EvidenceLoadFailure(EvidenceLoadError.unauthorized);
      case 403:
        return const EvidenceLoadFailure(EvidenceLoadError.forbidden);
      case 404:
        return const EvidenceLoadFailure(EvidenceLoadError.notFound);
    }
    if (error.response == null && error.type != DioExceptionType.cancel) {
      return const EvidenceLoadFailure(EvidenceLoadError.network);
    }
    return const EvidenceLoadFailure(EvidenceLoadError.unavailable);
  }

  String get message {
    switch (reason) {
      case EvidenceLoadError.unauthorized:
        return 'Sign in again to view this evidence.';
      case EvidenceLoadError.forbidden:
        return 'You do not have permission to view this evidence.';
      case EvidenceLoadError.notFound:
        return 'This evidence is no longer available.';
      case EvidenceLoadError.network:
        return 'Evidence could not be loaded. Check your connection.';
      case EvidenceLoadError.invalidUrl:
      case EvidenceLoadError.unavailable:
        return 'Evidence preview unavailable.';
    }
  }

  /// Short label for thumbnails.
  String get shortMessage {
    switch (reason) {
      case EvidenceLoadError.unauthorized:
        return 'Sign in';
      case EvidenceLoadError.forbidden:
        return 'No access';
      case EvidenceLoadError.notFound:
        return 'Not found';
      case EvidenceLoadError.network:
        return 'Offline';
      case EvidenceLoadError.invalidUrl:
      case EvidenceLoadError.unavailable:
        return 'Unavailable';
    }
  }

  @override
  String toString() => message;
}

final RegExp _evidencePath = RegExp(r'/incidents/[^/]+/evidence/[^/]+$');

/// Resolves a backend `file_url` (e.g. `/api/v1/incidents/{id}/evidence/{evidenceId}`)
/// against the API origin.
///
/// Returns null for anything that is not an evidence endpoint on that same origin
/// (empty values, local file paths, other hosts or schemes), so the bearer token that
/// the API client attaches is never sent anywhere else.
Uri? resolveEvidenceUri(String? fileUrl, {String? apiBaseUrl}) {
  final raw = fileUrl?.trim() ?? '';
  if (raw.isEmpty) return null;

  final base = Uri.tryParse(apiBaseUrl ?? Env.apiBaseUrl);
  final reference = Uri.tryParse(raw);
  if (base == null || reference == null || !base.hasScheme || base.host.isEmpty) return null;

  final resolved = base.resolveUri(reference);
  final sameOrigin = resolved.scheme == base.scheme && resolved.host == base.host && resolved.port == base.port;
  if (!sameOrigin || resolved.userInfo.isNotEmpty || resolved.hasQuery || resolved.hasFragment) return null;
  if (!_evidencePath.hasMatch(resolved.path)) return null;
  return resolved;
}

/// Downloads protected evidence through the authenticated API client.
///
/// The client's interceptor adds the `Authorization: Bearer` header (and refreshes an
/// expired token), so the evidence endpoint stays protected and no token is ever put
/// in a URL.
class EvidenceMediaLoader {
  final Dio _dio;
  final String? _apiBaseUrl;

  EvidenceMediaLoader(this._dio, {String? apiBaseUrl}) : _apiBaseUrl = apiBaseUrl;

  /// Throws only [EvidenceLoadFailure].
  Future<Uint8List> loadBytes(String fileUrl) async {
    final uri = resolveEvidenceUri(fileUrl, apiBaseUrl: _apiBaseUrl);
    if (uri == null) throw const EvidenceLoadFailure(EvidenceLoadError.invalidUrl);

    try {
      final response = await _dio.getUri<List<int>>(
        uri,
        options: Options(responseType: ResponseType.bytes, headers: {'Accept': '*/*'}),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) throw const EvidenceLoadFailure(EvidenceLoadError.unavailable);
      return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    } on DioException catch (e) {
      throw EvidenceLoadFailure.fromDioException(e);
    } on EvidenceLoadFailure {
      rethrow;
    } catch (_) {
      throw const EvidenceLoadFailure(EvidenceLoadError.unavailable);
    }
  }
}
