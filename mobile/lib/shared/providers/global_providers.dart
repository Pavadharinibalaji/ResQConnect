import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:resqconnect/core/network/dio_client.dart';
import 'package:resqconnect/core/storage/secure_storage.dart';
import 'package:resqconnect/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:resqconnect/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:resqconnect/features/auth/domain/repositories/auth_repository.dart';

// Secure storage adapter provider (Task 10)
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return const SecureStorage(FlutterSecureStorage());
});

// Basic Dio instance provider
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

// Hardened DioClient provider injecting secure storage credentials
final dioClientProvider = Provider<DioClient>((ref) {
  final dio = ref.watch(dioProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return DioClient(dio, secureStorage);
});

// Remote authentication datasource provider
final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRemoteDatasource(dioClient.instance);
});

// Main authentication repository provider mapping Clean Architecture boundaries (Task 7)
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDatasource = ref.watch(authRemoteDatasourceProvider);
  return AuthRepositoryImpl(remoteDatasource);
});
