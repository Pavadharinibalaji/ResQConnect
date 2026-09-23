import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqconnect/core/errors/api_error_parser.dart';
import 'package:resqconnect/core/errors/failures.dart';

DioException _httpError(int status, Object? body) {
  final options = RequestOptions(path: '/api/v1/profile');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

DioException _transportError(DioExceptionType type) =>
    DioException(requestOptions: RequestOptions(path: '/x'), type: type);

void main() {
  group('detail as a string', () {
    test('is shown as-is with its status code', () {
      final failure = ApiErrorParser.fromDioException(
        _httpError(403, {'detail': 'This role can only be granted by an administrator.'}),
      );
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'This role can only be granted by an administrator.');
      expect((failure as ServerFailure).statusCode, 403);
    });

    test('blank string falls back to the status message', () {
      expect(
        ApiErrorParser.messageFromResponseData({'detail': '   '}, statusCode: 404),
        'The requested item could not be found.',
      );
    });
  });

  group('detail as a list of validation errors (HTTP 422)', () {
    const secretInput = 'super-secret-token-value';

    test('uses msg with the field name and never the submitted input', () {
      final body = {
        'success': false,
        'detail': [
          {
            'type': 'value_error',
            'loc': ['body', 'username'],
            'msg': 'Value error, Username must be 3-30 characters long.',
            'input': secretInput,
            'ctx': {'error': 'Username must be 3-30 characters long.'},
          },
        ],
      };
      final failure = ApiErrorParser.fromDioException(_httpError(422, body));
      expect(failure.message, 'Username must be 3-30 characters long.');
      expect(failure.message, isNot(contains(secretInput)));
      expect((failure as ServerFailure).statusCode, 422);
    });

    test('prefixes the field for generic messages and joins several errors', () {
      final message = ApiErrorParser.messageFromResponseData({
        'detail': [
          {'type': 'missing', 'loc': ['body', 'display_name'], 'msg': 'Field required', 'input': {}},
          {'type': 'string_type', 'loc': ['body', 'emergency_role'], 'msg': 'Input should be a valid string', 'input': ['police']},
        ],
      }, statusCode: 422);
      expect(message, 'Display name: Field required\nEmergency role: Input should be a valid string');
      expect(message, isNot(contains('police')));
    });

    test('limits the number of messages shown', () {
      final message = ApiErrorParser.messageFromResponseData({
        'detail': [
          for (var i = 0; i < 5; i++) {'loc': ['body', 'f$i'], 'msg': 'Field required'},
        ],
      }, statusCode: 422);
      expect(message.split('\n').length, 4);
      expect(message, endsWith('(and 2 more)'));
    });

    test('handles malformed JSON errors whose loc has no field name', () {
      final message = ApiErrorParser.messageFromResponseData({
        'detail': [
          {'type': 'json_invalid', 'loc': ['body', 57], 'msg': 'JSON decode error', 'input': {}, 'ctx': {'error': 'Expecting value'}},
        ],
      }, statusCode: 422);
      expect(message, 'JSON decode error');
    });

    test('skips entries without a usable msg', () {
      final message = ApiErrorParser.messageFromResponseData({
        'detail': [null, 42, {'loc': 'body'}, {'msg': 7}, {'msg': ''}, 'Plain string entry'],
      }, statusCode: 422);
      expect(message, 'Plain string entry');
    });

    test('a list with nothing usable falls back to the 422 message', () {
      expect(
        ApiErrorParser.messageFromResponseData({'detail': [{}, null]}, statusCode: 422),
        'Some of the information provided is invalid.',
      );
    });
  });

  group('missing, null or unexpected detail', () {
    test('missing detail uses message', () {
      expect(ApiErrorParser.messageFromResponseData({'message': 'Custom failure'}, statusCode: 400), 'Custom failure');
    });

    test('missing detail and message uses the status message', () {
      expect(ApiErrorParser.messageFromResponseData({'success': false}, statusCode: 403),
          'You do not have permission to perform this action.');
    });

    test('null detail uses the status message', () {
      expect(ApiErrorParser.messageFromResponseData({'detail': null}, statusCode: 401),
          'Your session has expired. Please sign in again.');
    });

    test('server errors never show the raw body', () {
      final failure = ApiErrorParser.fromDioException(_httpError(502, '<html>Bad gateway</html>'));
      expect(failure.message, 'The server encountered a problem. Please try again later.');
    });

    test('unknown status with unexpected JSON uses the caller fallback', () {
      expect(
        ApiErrorParser.messageFromResponseData(['not', 'a', 'map'], statusCode: 418, fallbackMessage: 'Profile request failed.'),
        'Profile request failed.',
      );
      expect(ApiErrorParser.messageFromResponseData(null), ApiErrorParser.genericMessage);
    });

    test('detail given as an object with msg', () {
      expect(
        ApiErrorParser.messageFromResponseData({'detail': {'msg': 'Only one error', 'loc': ['query', 'type']}}),
        'Type: Only one error',
      );
    });
  });

  group('transport failures', () {
    test('timeouts', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final failure = ApiErrorParser.fromDioException(_transportError(type));
        expect(failure, isA<NetworkFailure>(), reason: type.name);
        expect(failure.message, ApiErrorParser.timeoutMessage);
      }
    });

    test('connection failure', () {
      final failure = ApiErrorParser.fromDioException(_transportError(DioExceptionType.connectionError));
      expect(failure, isA<NetworkFailure>());
      expect(failure.message, ApiErrorParser.unreachableMessage);
    });

    test('unknown error without a response', () {
      final failure = ApiErrorParser.fromDioException(_transportError(DioExceptionType.unknown));
      expect(failure, isA<NetworkFailure>());
    });
  });

  group('never throws', () {
    test('for any response body shape', () {
      final bodies = <Object?>[
        null, '', 'text', 0, 1.5, true, [], [null], {}, {'detail': 12}, {'detail': true},
        {'detail': [[]]}, {'detail': {'loc': null}}, {'detail': [{'msg': 'x', 'loc': [null, 3, '']}]},
        {'message': 5}, {1: 2}, Object(),
      ];
      for (final body in bodies) {
        for (final status in [null, 200, 400, 401, 403, 404, 409, 413, 415, 422, 429, 500, 599, 999]) {
          expect(() => ApiErrorParser.fromDioException(_httpError(status ?? 0, body)), returnsNormally,
              reason: '$status $body');
          expect(ApiErrorParser.messageFromResponseData(body, statusCode: status), isNotEmpty);
        }
      }
    });

    test('fromError passes failures through and hides other errors', () {
      const failure = ValidationFailure('Username taken');
      expect(ApiErrorParser.fromError(failure), same(failure));
      final other = ApiErrorParser.fromError(StateError('internal detail'), fallbackMessage: 'Could not save.');
      expect(other.message, 'Could not save.');
    });
  });
}
