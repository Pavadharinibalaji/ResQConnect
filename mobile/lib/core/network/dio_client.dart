import 'dart:io';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:resqconnect/core/constants/app_constants.dart';
import 'package:resqconnect/core/logger/app_logger.dart';
import 'package:resqconnect/core/storage/secure_storage.dart';

class DioClient {
  final Dio _dio;
  final SecureStorage _secureStorage;
  bool _isRefreshing = false;

  DioClient(this._dio, this._secureStorage) {
    _configureDio();
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      baseUrl: AppConstants.baseApiUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeoutMs),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeoutMs),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
      },
    );

    // Attach request interceptors
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          // 1. Generate and attach transaction Request ID
          final String requestId = const Uuid().v4();
          options.headers['X-Request-ID'] = requestId;

          // 2. Load and attach bearer token if logged in
          final token = await _secureStorage.read(AppConstants.keyAuthToken);
          if (token != null) {
            options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
          }

          AppLogger.debug('HTTP Request: ${options.method} -> ${options.path} [ID: $requestId]');
          return handler.next(options);
        },
        onResponse: (Response response, ResponseInterceptorHandler handler) {
          AppLogger.debug('HTTP Response: [Code ${response.statusCode}] <- ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          // Intercept HTTP 401 Unauthorized for Auto-Refresh
          final response = error.response;
          if (response != null && response.statusCode == 401) {
            // Check if we are already refreshing to avoid multiple calls
            if (!_isRefreshing) {
              _isRefreshing = true;
              AppLogger.info('Access token expired. Attempting automatic token refresh...');

              try {
                final refreshToken = await _secureStorage.read(AppConstants.keyRefreshToken);

                if (refreshToken != null) {
                  // Perform isolated refresh call using a new temporary Dio instance
                  final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.baseApiUrl));
                  final refreshResponse = await refreshDio.post(
                    '/auth/refresh',
                    data: {'refresh_token': refreshToken},
                  );

                  if (refreshResponse.statusCode == 200) {
                    final data = refreshResponse.data['data'] as Map<String, dynamic>;
                    final newAccessToken = data['access_token'] as String;
                    final newRefreshToken = data['refresh_token'] as String;

                    // Write rotated tokens back to secure storage
                    await _secureStorage.write(AppConstants.keyAuthToken, newAccessToken);
                    await _secureStorage.write(AppConstants.keyRefreshToken, newRefreshToken);

                    _isRefreshing = false;
                    AppLogger.info('Token refresh successful. Retrying original request.');

                    // Retry original failed request with the new access token
                    final RequestOptions options = error.requestOptions;
                    options.headers[HttpHeaders.authorizationHeader] = 'Bearer $newAccessToken';
                    
                    // Create new request
                    final retryResponse = await _dio.fetch(options);
                    return handler.resolve(retryResponse);
                  }
                }
              } catch (refreshErr) {
                AppLogger.error('Forced logout. Token refresh session failed', error: refreshErr);
              } finally {
                _isRefreshing = false;
              }

              // Refresh failed - force logout by clearing storage
              await _secureStorage.clearAll();
            }
          }

          // Forward original error if refresh is not applicable or failed
          return handler.next(error);
        },
      ),
    );
  }

  Dio get instance => _dio;
}
