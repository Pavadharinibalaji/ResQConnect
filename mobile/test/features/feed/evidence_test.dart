import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqconnect/core/constants/app_constants.dart';
import 'package:resqconnect/core/errors/failures.dart';
import 'package:resqconnect/core/network/dio_client.dart';
import 'package:resqconnect/features/feed/data/evidence_media_loader.dart';
import 'package:resqconnect/features/feed/data/repositories/incident_repository_impl.dart';
import 'package:resqconnect/features/feed/domain/evidence_upload.dart';
import 'package:resqconnect/features/feed/domain/models/evidence_model.dart';
import 'package:resqconnect/features/feed/domain/repositories/incident_repository.dart';
import 'package:resqconnect/features/feed/presentation/providers/incident_provider.dart';
import 'package:resqconnect/features/feed/presentation/widgets/evidence_media.dart';

import '../../helpers/fake_http.dart';

const _api = 'http://api.test:8000';
const _evidenceUrl = '/api/v1/incidents/0b8e/evidence/77aa';
const _token = 'test-access-token';

/// The real authenticated client (bearer interceptor) over a fake transport.
({Dio dio, FakeHttpAdapter adapter}) _authenticatedClient(FutureOr<ResponseBody> Function(RequestOptions) handler) {
  final adapter = FakeHttpAdapter(handler);
  final client = DioClient(Dio(), FakeSecureStorage({AppConstants.keyAuthToken: _token}));
  client.instance.httpClientAdapter = adapter;
  return (dio: client.instance, adapter: adapter);
}

class _FakeLoader extends EvidenceMediaLoader {
  _FakeLoader(this.result) : super(Dio());

  final Future<Uint8List> Function() result;
  final List<String> requested = [];

  @override
  Future<Uint8List> loadBytes(String fileUrl) {
    requested.add(fileUrl);
    return result();
  }
}

Future<void> _pumpEvidence(WidgetTester tester, _FakeLoader loader, {bool compact = false}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [evidenceMediaLoaderProvider.overrideWithValue(loader)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: AuthenticatedEvidenceImage(fileUrl: _evidenceUrl, compact: compact),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _RecordingRepository implements IncidentRepository {
  _RecordingRepository(this.failFor);

  final Map<String, Object> failFor;
  final List<String> uploaded = [];

  @override
  Future<IncidentEvidenceModel> uploadEvidence(String incidentId, String filePath, String type) async {
    final error = failFor[filePath];
    if (error != null) throw error;
    uploaded.add(filePath);
    return IncidentEvidenceModel(id: 'e-$filePath', incidentId: incidentId, type: type, fileUrl: _evidenceUrl);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('resolveEvidenceUri', () {
    test('resolves the backend evidence path against the API origin', () {
      expect(resolveEvidenceUri(_evidenceUrl, apiBaseUrl: _api).toString(), '$_api$_evidenceUrl');
      expect(resolveEvidenceUri('$_api$_evidenceUrl', apiBaseUrl: _api).toString(), '$_api$_evidenceUrl');
    });

    test('rejects missing, malformed, foreign and non-evidence URLs', () {
      for (final url in [
        null,
        '',
        '   ',
        'https://evil.example$_evidenceUrl',
        'http://api.test:9999$_evidenceUrl',
        'https://api.test:8000$_evidenceUrl',
        'file:///data/user/0/app/cache/photo.jpg',
        '/data/user/0/app/cache/photo.jpg',
        r'C:\Users\me\photo.jpg',
        '/static/uploads/evidence/photo.jpg',
        '$_evidenceUrl?token=abc',
        'http://user:pw@api.test:8000$_evidenceUrl',
        '::not a url::',
      ]) {
        expect(resolveEvidenceUri(url, apiBaseUrl: _api), isNull, reason: '$url');
      }
    });
  });

  group('EvidenceMediaLoader with the authenticated client', () {
    test('sends the bearer token in a header, never in the URL', () async {
      final client = _authenticatedClient((_) => bytesResponse(kOnePixelPng, 200));
      final bytes = await EvidenceMediaLoader(client.dio, apiBaseUrl: _api).loadBytes(_evidenceUrl);

      expect(bytes, kOnePixelPng);
      final request = client.adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.toString(), '$_api$_evidenceUrl');
      expect(request.headers[HttpHeaders.authorizationHeader], 'Bearer $_token');
      expect(request.uri.hasQuery, isFalse);
      expect(request.uri.toString(), isNot(contains(_token)));
    });

    test('never contacts a foreign host or an invalid URL', () async {
      final client = _authenticatedClient((_) => bytesResponse(kOnePixelPng, 200));
      final loader = EvidenceMediaLoader(client.dio, apiBaseUrl: _api);
      for (final url in ['https://evil.example$_evidenceUrl', '', '/tmp/local.jpg']) {
        await expectLater(
          loader.loadBytes(url),
          throwsA(isA<EvidenceLoadFailure>().having((f) => f.reason, 'reason', EvidenceLoadError.invalidUrl)),
        );
      }
      expect(client.adapter.requests, isEmpty);
    });

    final cases = <String, (FutureOr<ResponseBody> Function(RequestOptions), EvidenceLoadError)>{
      '401': ((_) => jsonResponse({'detail': 'Could not validate credentials'}, 401), EvidenceLoadError.unauthorized),
      '403': ((_) => jsonResponse({'detail': 'You are not allowed to access evidence for this incident.'}, 403),
          EvidenceLoadError.forbidden),
      '404': ((_) => jsonResponse({'detail': 'Evidence not found.'}, 404), EvidenceLoadError.notFound),
      '500': ((_) => jsonResponse({'detail': 'Internal server error'}, 500), EvidenceLoadError.unavailable),
      'empty body': ((_) => bytesResponse(const [], 200), EvidenceLoadError.unavailable),
      'connection failure': (
        (o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError),
        EvidenceLoadError.network
      ),
      'timeout': (
        (o) => throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout),
        EvidenceLoadError.network
      ),
    };
    cases.forEach((name, spec) {
      test('$name maps to ${spec.$2.name}', () async {
        final client = _authenticatedClient(spec.$1);
        await expectLater(
          EvidenceMediaLoader(client.dio, apiBaseUrl: _api).loadBytes(_evidenceUrl),
          throwsA(isA<EvidenceLoadFailure>().having((f) => f.reason, 'reason', spec.$2)),
        );
      });
    });
  });

  group('AuthenticatedEvidenceImage', () {
    testWidgets('shows the image when evidence loads', (tester) async {
      final loader = _FakeLoader(() async => Uint8List.fromList(kOnePixelPng));
      await _pumpEvidence(tester, loader);

      expect(loader.requested, [_evidenceUrl]);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(EvidenceUnavailable), findsNothing);
    });

    final fallbacks = {
      EvidenceLoadError.unauthorized: 'Sign in again to view this evidence.',
      EvidenceLoadError.forbidden: 'You do not have permission to view this evidence.',
      EvidenceLoadError.notFound: 'This evidence is no longer available.',
      EvidenceLoadError.network: 'Evidence could not be loaded. Check your connection.',
      EvidenceLoadError.invalidUrl: 'Evidence preview unavailable.',
    };
    fallbacks.forEach((reason, message) {
      testWidgets('shows a fallback for ${reason.name}', (tester) async {
        await _pumpEvidence(tester, _FakeLoader(() async => throw EvidenceLoadFailure(reason)));
        expect(find.byType(Image), findsNothing);
        expect(find.text(message), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('thumbnail fallback uses the short label', (tester) async {
      await _pumpEvidence(
        tester,
        _FakeLoader(() async => throw const EvidenceLoadFailure(EvidenceLoadError.forbidden)),
        compact: true,
      );
      expect(find.text('No access'), findsOneWidget);
    });

    testWidgets('an unexpected error still shows a fallback', (tester) async {
      await _pumpEvidence(tester, _FakeLoader(() async => throw StateError('boom')));
      expect(find.text('Evidence preview unavailable.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('evidence upload errors', () {
    late Directory tempDir;
    late String photoPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('resq_evidence_test');
      photoPath = '${tempDir.path}/photo.png';
      await File(photoPath).writeAsBytes(kOnePixelPng);
    });

    tearDown(() => tempDir.delete(recursive: true));

    test('a rejected upload throws the backend reason instead of faking success', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse({'detail': 'Photo evidence exceeds the 10 MB limit.'}, 413));
      final repo = IncidentRepositoryImpl(fakeDio(adapter), FakeSecureStorage());

      await expectLater(
        repo.uploadEvidence('0b8e', photoPath, 'photo'),
        throwsA(isA<ServerFailure>()
            .having((f) => f.statusCode, 'statusCode', 413)
            .having((f) => f.message, 'message', 'Photo evidence exceeds the 10 MB limit.')),
      );
      expect(adapter.requests.single.method, 'POST');
    });

    test('a network failure during upload surfaces as a NetworkFailure', () async {
      final adapter = FakeHttpAdapter(
        (o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError),
      );
      await expectLater(
        IncidentRepositoryImpl(fakeDio(adapter), FakeSecureStorage()).uploadEvidence('0b8e', photoPath, 'photo'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('an unreadable file surfaces an error', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse({}, 201));
      await expectLater(
        IncidentRepositoryImpl(fakeDio(adapter), FakeSecureStorage())
            .uploadEvidence('0b8e', '${tempDir.path}/missing.png', 'photo'),
        throwsA(isA<Failure>().having((f) => f.message, 'message', 'The evidence file could not be read or uploaded.')),
      );
      expect(adapter.requests, isEmpty);
    });

    test('a successful upload returns the protected evidence URL', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse({
            'success': true,
            'data': {'id': '77aa', 'incident_id': '0b8e', 'type': 'photo', 'file_url': _evidenceUrl},
          }, 201));
      final evidence =
          await IncidentRepositoryImpl(fakeDio(adapter), FakeSecureStorage()).uploadEvidence('0b8e', photoPath, 'photo');
      expect(evidence.fileUrl, _evidenceUrl);
    });

    test('uploadEvidenceFiles reports each failure to the UI', () async {
      final repo = _RecordingRepository({
        'b.mp4': const ServerFailure('Video evidence exceeds the 50 MB limit.', statusCode: 413),
        'c.jpg': const NetworkFailure('Unable to reach the ResQConnect server.'),
      });
      final result = await uploadEvidenceFiles(repo, 'inc-1', [
        (path: 'a.jpg', type: 'photo'),
        (path: 'b.mp4', type: 'video'),
        (path: 'c.jpg', type: 'photo'),
      ]);

      expect(repo.uploaded, ['a.jpg']);
      expect(result.attempted, 3);
      expect(result.succeeded, 1);
      expect(result.allSucceeded, isFalse);
      expect(result.failureSummary, contains('2 of 3 evidence files could not be uploaded'));
      expect(result.failureSummary, contains('Video evidence exceeds the 50 MB limit.'));
      expect(result.failureSummary, contains('Unable to reach the ResQConnect server.'));
    });

    test('uploadEvidenceFiles reports success when every file uploads', () async {
      final result = await uploadEvidenceFiles(_RecordingRepository({}), 'inc-1', [(path: 'a.jpg', type: 'photo')]);
      expect(result.allSucceeded, isTrue);
      expect(result.failureSummary, isNull);
    });
  });
}
