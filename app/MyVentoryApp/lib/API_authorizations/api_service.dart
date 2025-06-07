import 'package:http/http.dart' as http;
import 'package:my_ventory_mobile/Config/config.dart';
import 'auth_service.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<http.Response> get(String endpoint,
      {bool skipAuth = false, BuildContext? context}) async {
    http.Response response = await _doGet(endpoint, skipAuth: skipAuth);
    if (response.statusCode == 401 && !skipAuth) {
      final refreshed = await AuthService.refreshTokenIfNeeded();
      if (refreshed) {
        response = await _doGet(endpoint, skipAuth: skipAuth);
      } else {
        if (context != null) {
          await AuthService.logout();
          if (context.mounted) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (route) => false);
          }
        }
      }
    }
    return response;
  }

  Future<http.Response> _doGet(String endpoint, {bool skipAuth = false}) async {
    final token = skipAuth ? '' : await AuthService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (!skipAuth) 'Authorization': 'Bearer $token',
    };
    return await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
      headers: headers,
    );
  }

  Future<http.Response> post(String endpoint, dynamic body,
      {bool isMultipart = false,
      bool skipAuth = false,
      BuildContext? context,
      Map<String, String>? customHeaders}) async {
    http.Response response = await _doPost(endpoint, body,
        isMultipart: isMultipart,
        skipAuth: skipAuth,
        customHeaders: customHeaders);
    if (response.statusCode == 401 && !skipAuth) {
      final refreshed = await AuthService.refreshTokenIfNeeded();
      if (refreshed) {
        response = await _doPost(endpoint, body,
            isMultipart: isMultipart,
            skipAuth: skipAuth,
            customHeaders: customHeaders);
      } else {
        if (context != null) {
          await AuthService.logout();
          if (context.mounted) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (route) => false);
          }
        }
      }
    }
    return response;
  }

  Future<http.Response> _doPost(String endpoint, dynamic body,
      {bool isMultipart = false,
      bool skipAuth = false,
      Map<String, String>? customHeaders}) async {
    final token = skipAuth ? '' : await AuthService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (!skipAuth) 'Authorization': 'Bearer $token',
      if (customHeaders != null) ...customHeaders,
    };

    if (isMultipart && body is Map<String, String>) {
      final request = http.MultipartRequest(
          'POST', Uri.parse('${AppConfig.apiBaseUrl}$endpoint'))
        ..fields.addAll(body);

      if (!skipAuth) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final response = await request.send();
      return await http.Response.fromStream(response);
    }

    final encodedBody = (body is String) ? body : jsonEncode(body);
    return await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
      headers: headers,
      body: encodedBody,
    );
  }

  Future<http.Response> multipartPost(
    String endpoint,
    Map<String, String> fields,
    List<http.MultipartFile> files, {
    bool skipAuth = false,
    BuildContext? context,
  }) async {
    final token = skipAuth ? '' : await AuthService.getToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri)
      ..fields.addAll(fields)
      ..files.addAll(files);

    if (!skipAuth) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['accept'] = '*/*';

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401 && !skipAuth) {
      final refreshed = await AuthService.refreshTokenIfNeeded();
      if (refreshed) {
        final newToken = await AuthService.getToken();
        request.headers['Authorization'] = 'Bearer $newToken';
        final retryStreamedResponse = await request.send();
        return await http.Response.fromStream(retryStreamedResponse);
      } else {
        if (context != null) {
          await AuthService.logout();
          if (context.mounted) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (route) => false);
          }
        }
      }
    }
    return response;
  }

  Future<http.Response> put(String endpoint, dynamic body,
      {bool skipAuth = false, BuildContext? context}) async {
    http.Response response = await _doPut(endpoint, body, skipAuth: skipAuth);
    if (response.statusCode == 401 && !skipAuth) {
      final refreshed = await AuthService.refreshTokenIfNeeded();
      if (refreshed) {
        response = await _doPut(endpoint, body, skipAuth: skipAuth);
      } else {
        if (context != null) {
          await AuthService.logout();
          if (context.mounted) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (route) => false);
          }
        }
      }
    }
    return response;
  }

  Future<http.Response> _doPut(String endpoint, dynamic body,
      {bool skipAuth = false}) async {
    final token = skipAuth ? '' : await AuthService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (!skipAuth) 'Authorization': 'Bearer $token',
    };
    final encodedBody = (body is String) ? body : jsonEncode(body);
    return await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
      headers: headers,
      body: encodedBody,
    );
  }

  Future<http.Response> multipartPut(
    String endpoint,
    Map<String, String> fields,
    List<http.MultipartFile> files, {
    bool skipAuth = false,
    BuildContext? context,
  }) async {
    final token = skipAuth ? '' : await AuthService.getToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final request = http.MultipartRequest('PUT', uri)
      ..fields.addAll(fields)
      ..files.addAll(files);

    if (!skipAuth) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['accept'] = '*/*';

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 401 && !skipAuth) {
      final refreshed = await AuthService.refreshTokenIfNeeded();
      if (refreshed) {
        final newToken = await AuthService.getToken();
        request.headers['Authorization'] = 'Bearer $newToken';
        final retryStreamedResponse = await request.send();
        return await http.Response.fromStream(retryStreamedResponse);
      } else {
        if (context != null) {
          await AuthService.logout();
          if (context.mounted) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (route) => false);
          }
        }
      }
    }
    return response;
  }

  Future<http.Response> delete(String endpoint,
      {dynamic body, bool skipAuth = false, BuildContext? context}) async {
    http.Response response =
        await _doDelete(endpoint, body: body, skipAuth: skipAuth);
    if (response.statusCode == 401 && !skipAuth) {
      final refreshed = await AuthService.refreshTokenIfNeeded();
      if (refreshed) {
        response = await _doDelete(endpoint, body: body, skipAuth: skipAuth);
      } else {
        if (context != null) {
          await AuthService.logout();
          if (context.mounted) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (route) => false);
          }
        }
      }
    }
    return response;
  }

  Future<http.Response> _doDelete(String endpoint,
      {dynamic body, bool skipAuth = false}) async {
    final token = skipAuth ? '' : await AuthService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (!skipAuth) 'Authorization': 'Bearer $token',
    };
    final encodedBody = (body is String) ? body : jsonEncode(body);
    return await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
      headers: headers,
      body: encodedBody,
    );
  }
}
