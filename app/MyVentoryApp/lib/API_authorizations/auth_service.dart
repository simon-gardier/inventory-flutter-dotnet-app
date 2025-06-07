import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static final _storage = const FlutterSecureStorage();
  static const String userDataKey = 'userData';
  static const String _tokenKey = 'jwt_token';
  static const String _refreshTokenKey = 'refresh_token';
  static Completer<bool>? _refreshCompleter;

  // Gets token from stored user data
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  // Gets userId from stored user data
  static Future<int?> getUserId() async {
    final userDataString = await _storage.read(key: userDataKey);

    if (userDataString != null) {
      final userData = json.decode(userDataString);
      return userData['userId'] as int?;
    }
    return null;
  }

  // Checks if user is logged in (token exists)
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Stores user data upon login
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(key: userDataKey, value: json.encode(userData));
    // Also store token separately for compatibility with first implementation
    if (userData.containsKey('token')) {
      await _storage.write(key: _tokenKey, value: userData['token']);
    }
    if (userData.containsKey('refreshToken')) {
      await _storage.write(
          key: _refreshTokenKey, value: userData['refreshToken']);
    }
  }

  Future<void> saveAuthData(Map<String, dynamic> userData) async {
    await _storage.write(key: _tokenKey, value: userData['token']);
    await _storage.write(key: userDataKey, value: json.encode(userData));
  }

  static Future<void> updateTokens(String token, String refreshToken) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    // Also update in userData
    final userDataString = await _storage.read(key: userDataKey);
    if (userDataString != null) {
      final userData = json.decode(userDataString);
      userData['token'] = token;
      userData['refreshToken'] = refreshToken;
      await _storage.write(key: userDataKey, value: json.encode(userData));
    }
  }

  // Gets user full name
  static Future<String?> getUserFullName() async {
    final userDataString = await _storage.read(key: userDataKey);

    if (userDataString != null) {
      final userData = json.decode(userDataString);
      final firstName = userData['firstName'] as String?;
      final lastName = userData['lastName'] as String?;

      if (firstName != null && lastName != null) {
        return '$firstName $lastName';
      } else if (firstName != null) {
        return firstName;
      } else if (lastName != null) {
        return lastName;
      }
    }
    return null;
  }

  // Checks if token has expired
  static Future<bool> isTokenExpired() async {
    final token = await getToken();
    if (token == null) return true;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(decoded);
      if (payloadMap.containsKey('exp')) {
        final exp = payloadMap['exp'];
        final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        return DateTime.now().isAfter(expDate);
      }
    } catch (e) {
      return true;
    }

    return false;
  }

  // Get user data - instance method for compatibility with first implementation
  Future<Map<String, dynamic>?> getUserData() async {
    final userDataStr = await _storage.read(key: userDataKey);
    if (userDataStr != null) {
      return json.decode(userDataStr);
    }
    return null;
  }

  // Logout - clear stored user data
  static Future<void> logout() async {
    await _storage.delete(key: userDataKey);
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  // Instance method version of logout for compatibility with first implementation
  Future<void> logoutInstance() async {
    await logout();
  }

  static Future<bool> refreshTokenIfNeeded() async {
    // if a refresh completer is already in progress, wait for it to complete
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(false);
        _refreshCompleter = null;
        return false;
      }

      final response = await ApiService().post(
        '/auth/refresh-token',
        json.encode({'refreshToken': refreshToken}),
        skipAuth: true,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newToken = data['jwtToken'];
        final newRefreshToken = data['refreshToken'];
        await updateTokens(newToken, newRefreshToken);
        _refreshCompleter!.complete(true);
        _refreshCompleter = null;
        return true;
      } else {
        await logout();
        _refreshCompleter!.complete(false);
        _refreshCompleter = null;
        return false;
      }
    } catch (e) {
      await logout();
      _refreshCompleter?.complete(false);
      _refreshCompleter = null;
      return false;
    }
  }
}
