import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:resqconnect/core/logger/app_logger.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;

  const SecureStorage(this._storage);

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      AppLogger.debug('Successfully stored key: $key');
    } catch (e, stack) {
      AppLogger.error('Failed to write securely for key: $key', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value;
    } catch (e, stack) {
      AppLogger.error('Failed to read securely for key: $key', error: e, stackTrace: stack);
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
      AppLogger.debug('Successfully deleted key: $key');
    } catch (e, stack) {
      AppLogger.error('Failed to delete securely for key: $key', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      AppLogger.info('Cleared all secure keychain entries.');
    } catch (e, stack) {
      AppLogger.error('Failed to clear secure storage', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
