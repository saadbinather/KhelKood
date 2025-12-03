import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Storage service for managing local data
/// Implements Single Responsibility Principle - only handles storage operations
abstract class IStorageService {
  Future<String?> getAuthToken();
  Future<void> saveAuthToken(String token);
  Future<void> removeAuthToken();
  Future<String?> getString(String key);
  Future<void> saveString(String key, String value);
  Future<void> remove(String key);
  Future<void> clear();
}

class StorageService implements IStorageService {
  static StorageService? _instance;
  static SharedPreferences? _preferences;

  // Private constructor for singleton pattern
  StorageService._();

  // Factory constructor returns singleton instance
  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._();
    _preferences ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  @override
  Future<String?> getAuthToken() async {
    try {
      return _preferences?.getString(AppConstants.authTokenKey);
    } catch (e) {
      print('Error getting auth token: $e');
      return null;
    }
  }

  @override
  Future<void> saveAuthToken(String token) async {
    try {
      await _preferences?.setString(AppConstants.authTokenKey, token);
    } catch (e) {
      print('Error saving auth token: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeAuthToken() async {
    try {
      await _preferences?.remove(AppConstants.authTokenKey);
    } catch (e) {
      print('Error removing auth token: $e');
      rethrow;
    }
  }

  @override
  Future<String?> getString(String key) async {
    try {
      return _preferences?.getString(key);
    } catch (e) {
      print('Error getting string for key $key: $e');
      return null;
    }
  }

  @override
  Future<void> saveString(String key, String value) async {
    try {
      await _preferences?.setString(key, value);
    } catch (e) {
      print('Error saving string for key $key: $e');
      rethrow;
    }
  }

  @override
  Future<void> remove(String key) async {
    try {
      await _preferences?.remove(key);
    } catch (e) {
      print('Error removing key $key: $e');
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _preferences?.clear();
    } catch (e) {
      print('Error clearing storage: $e');
      rethrow;
    }
  }
}

