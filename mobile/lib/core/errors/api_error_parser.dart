import 'package:dio/dio.dart';
import 'package:resqconnect/core/errors/failures.dart';

/// Converts backend error responses and transport failures into user-facing [Failure]s.
///
/// The backend returns `detail` either as a string (handled 4xx errors) or, for
/// HTTP 422, as a list of validation errors shaped `{type, loc, msg, input, ctx}`.
/// Only `msg` (with its field name) is shown: the submitted `input` is never echoed.
/// Nothing here throws, whatever shape the response body has.
class ApiErrorParser {
  ApiErrorParser._();

  static const String genericMessage = 'Something went wrong. Please try again.';
  static const String timeoutMessage = 'The request timed out. Check your connection and try again.';
  static const String unreachableMessage =
      'Unable to reach the ResQConnect server. Check your connection and try again.';

  static const int _maxValidationMessages = 3;
  static const Set<String> _locationRoots = {'body', 'query', 'path', 'header', 'cookie'};

  /// Maps any [DioException] (timeouts, connection failures, HTTP errors) to a [Failure].
  static Failure fromDioException(DioException error, {String? fallbackMessage}) {
    try {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return const NetworkFailure(timeoutMessage);
        case DioExceptionType.connectionError:
          return const NetworkFailure(unreachableMessage);
        case DioExceptionType.cancel:
          return const NetworkFailure('The request was cancelled.');
        case DioExceptionType.badCertificate:
          return const NetworkFailure('A secure connection to the server could not be established.');
        default:
          break;
      }

      final response = error.response;
      if (response == null) {
        return const NetworkFailure(unreachableMessage);
      }
      final statusCode = response.statusCode;
      return ServerFailure(
        messageFromResponseData(response.data, statusCode: statusCode, fallbackMessage: fallbackMessage),
        statusCode: statusCode,
      );
    } catch (_) {
      return ServerFailure(fallbackMessage ?? genericMessage);
    }
  }

  /// Maps any thrown object to a [Failure]; existing failures pass through unchanged.
  static Failure fromError(Object error, {String? fallbackMessage}) {
    if (error is Failure) return error;
    if (error is DioException) return fromDioException(error, fallbackMessage: fallbackMessage);
    return ServerFailure(fallbackMessage ?? genericMessage);
  }

  /// Extracts a readable message from an error response body of any shape.
  static String messageFromResponseData(Object? data, {int? statusCode, String? fallbackMessage}) {
    try {
      if (data is Map) {
        final fromDetail = _messageFromDetail(data['detail']);
        if (fromDetail != null) return fromDetail;
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) return message.trim();
      }
    } catch (_) {
      // Fall through to the status-based message.
    }
    return messageForStatus(statusCode) ?? fallbackMessage ?? genericMessage;
  }

  /// A generic message for well-known HTTP status codes, or null.
  static String? messageForStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'The request could not be processed.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested item could not be found.';
      case 409:
        return 'This conflicts with existing data.';
      case 413:
        return 'The file is too large to upload.';
      case 415:
        return 'This file type is not supported.';
      case 422:
        return 'Some of the information provided is invalid.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'The server encountered a problem. Please try again later.';
    }
    return null;
  }

  static String? _messageFromDetail(Object? detail) {
    if (detail is String) {
      final text = detail.trim();
      return text.isEmpty ? null : text;
    }
    if (detail is Map) return _validationMessage(detail);
    if (detail is List) {
      final messages = <String>[];
      for (final entry in detail) {
        final message = _validationMessage(entry);
        if (message != null && !messages.contains(message)) messages.add(message);
      }
      if (messages.isEmpty) return null;
      final shown = messages.take(_maxValidationMessages).join('\n');
      final hidden = messages.length - _maxValidationMessages;
      return hidden > 0 ? '$shown\n(and $hidden more)' : shown;
    }
    return null;
  }

  static String? _validationMessage(Object? entry) {
    if (entry is String) {
      final text = entry.trim();
      return text.isEmpty ? null : text;
    }
    if (entry is! Map) return null;

    final rawMsg = entry['msg'];
    if (rawMsg is! String || rawMsg.trim().isEmpty) return null;
    // Pydantic prefixes custom validator messages with "Value error, ".
    var message = rawMsg.trim().replaceFirst(RegExp(r'^Value error,\s*'), '');

    final field = _fieldLabel(entry['loc']);
    if (field != null && !message.toLowerCase().startsWith(field.toLowerCase())) {
      message = '$field: $message';
    }
    return message;
  }

  static String? _fieldLabel(Object? loc) {
    if (loc is! List) return null;
    for (final part in loc.reversed) {
      if (part is String && part.isNotEmpty && !_locationRoots.contains(part)) {
        final words = part.replaceAll('_', ' ').trim();
        if (words.isEmpty) return null;
        return words[0].toUpperCase() + words.substring(1);
      }
    }
    return null;
  }
}
