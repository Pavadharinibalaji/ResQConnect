import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:resqconnect/core/storage/secure_storage.dart';

/// In-memory Dio transport: records each request and answers it with [handler].
///
/// The handler may throw a [DioException] to simulate timeouts or connection loss.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Consume the body like a real transport does (this also closes multipart file streams).
    await requestStream?.drain<void>();
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? body, int statusCode) => ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody bytesResponse(List<int> bytes, int statusCode, {String contentType = 'image/png'}) =>
    ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );

Dio fakeDio(FakeHttpAdapter adapter, {String baseUrl = 'http://api.test:8000/api/v1'}) {
  return Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;
}

/// Secure storage backed by a map (no platform channels).
class FakeSecureStorage implements SecureStorage {
  FakeSecureStorage([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clearAll() async => values.clear();
}

/// A valid 1x1 transparent PNG.
const List<int> kOnePixelPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];
