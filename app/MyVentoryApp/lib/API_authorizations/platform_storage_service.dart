import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A platform-aware storage service that works across different platforms
/// including web, mobile, and desktop (Windows)
class PlatformStorageService {
  static final PlatformStorageService _instance =
      PlatformStorageService._internal();
  factory PlatformStorageService() => _instance;
  PlatformStorageService._internal();

  // Web and mobile platforms use FlutterSecureStorage
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // For Windows and other platforms where secure storage might fail, we'll use in-memory storage
  static final Map<String, String> _inMemoryStorage = {};

  /// Reads a value from storage
  Future<String?> read({required String key}) async {
    try {
      // First try using secure storage
      return await _secureStorage.read(key: key);
    } catch (e) {
      // Fallback to in-memory storage
      return _inMemoryStorage[key];
    }
  }

  /// Writes a value to storage
  Future<void> write({required String key, required String value}) async {
    try {
      // First try using secure storage
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      // Fallback to in-memory storage
      _inMemoryStorage[key] = value;
    }
  }

  /// Deletes a value from storage
  Future<void> delete({required String key}) async {
    try {
      // First try using secure storage
      await _secureStorage.delete(key: key);
    } catch (e) {
      // Fallback to in-memory storage
      _inMemoryStorage.remove(key);
    }
  }

  /// Reads all data from storage
  Future<Map<String, String>> readAll() async {
    try {
      // First try using secure storage
      return await _secureStorage.readAll();
    } catch (e) {
      // Fallback to in-memory storage
      return Map<String, String>.from(_inMemoryStorage);
    }
  }

  /// Deletes all data from storage
  Future<void> deleteAll() async {
    try {
      // First try using secure storage
      await _secureStorage.deleteAll();
    } catch (e) {
      // Fallback to in-memory storage
      _inMemoryStorage.clear();
    }
  }
}
