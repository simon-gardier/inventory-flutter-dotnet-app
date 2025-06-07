import 'package:http/http.dart' as http;
import 'package:my_ventory_mobile/Custom_exception/custom_login_exception.dart';
import 'dart:convert';
import '../Model/user.dart';
import '../Model/item.dart';
import '../Model/location.dart';
import '../Config/config.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../API_authorizations/auth_service.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';

class UserController {
  static String get apiUrl => "${AppConfig.apiBaseUrl}/users";

  static Future<bool> loginUserAndSaveData({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final response = await ApiService().post(
        '/users/login',
        jsonEncode({
          'usernameOrEmail': usernameOrEmail,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        await AuthService.saveUserData(userData);
        return true;
      } else if (response.statusCode == 401) {
          // Vérifie si le message d'erreur indique un compte bloqué
          final responseBody = jsonDecode(response.body);
          if (responseBody['detail'] != null &&
              responseBody['detail'].contains('Account is locked')) {
            final keyword = "Account";
            final lockMessage = extractMessage(responseBody['detail'], keyword);
            throw CustomLoginException(lockMessage);
        } else {
          final responseBody = jsonDecode(response.body);
          final errorMessage = responseBody['detail'] ?? 'An unknown error occurred';
          throw CustomLoginException(errorMessage);
        }
      }
      return false;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<bool> loginUserSsoAndSaveData(
      {required String email,
      required String token,
      required String refreshToken}) async {
    try {
      final response = await ApiService().post(
        '/users/login-without-password',
        jsonEncode({'email': email}),
        customHeaders: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        userData['token'] = token;
        userData['refreshToken'] = refreshToken;
        await AuthService.saveUserData(userData);
        return true;
      } else {
        // Parse the error message from the response
        final errorData = jsonDecode(response.body);
        String errorMessage = 'Invalid credentials';
        if (errorData['detail'] != null) {
          errorMessage = errorData['detail'];
        } else if (errorData['message'] != null) {
          errorMessage = errorData['message'];
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  static Future<Map<String, dynamic>> createUser({
    required String userName,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    File? imageFile,
  }) async {
    try {
      final fields = {
        'userName': userName,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
      };
      final files = <http.MultipartFile>[];
      if (imageFile != null) {
        final extension =
            path.extension(imageFile.path).toLowerCase().replaceAll('.', '');
        final mimeType =
            extension == 'jpg' || extension == 'jpeg' ? 'jpeg' : extension;
        files.add(await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', mimeType),
        ));
      }
      final response = await ApiService().multipartPost(
        '/users',
        fields,
        files,
      );
      final responseBody = response.body;
      if (response.statusCode == 201) {
        return jsonDecode(responseBody);
      } else if (response.statusCode == 400) {
        throw Exception(
            "Bad Request: Invalid data provided. Details: $responseBody");
      } else if (response.statusCode == 500) {
        throw Exception("Server Error: Please try again later.");
      } else {
        throw Exception(
            "Failed to create user. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to create user: $e");
    }
  }

  static Future<UserAccount?> loginUser({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final response = await ApiService().post(
        '/users/login',
        jsonEncode({
          'usernameOrEmail': usernameOrEmail,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return UserAccount.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<InventoryItem>?> getItemsOfUser(int userId) async {
    try {
      final response = await ApiService().get('/users/$userId/items');
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        List<dynamic> itemsJson = jsonData['items'] ?? [];
        List<InventoryItem> items = itemsJson
            .map((itemJson) => InventoryItem.fromJson(itemJson))
            .toList();
        return items;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication expired");
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<List<Location>?> getLocationsOfUser(int userId) async {
    try {
      final response = await ApiService().get('/users/$userId/locations');
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        List<Location> locations =
            jsonData.map((json) => Location.fromJson(json)).toList();
        return locations;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication expired");
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get locations: $e');
    }
  }

  static Future<List<ItemAttribute>?> getAttributesOfUser(int userId) async {
    try {
      final response = await ApiService().get('/users/$userId/attributes');
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        List<ItemAttribute> attributes =
            jsonData.map((json) => ItemAttribute.fromJson(json)).toList();
        return attributes;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication expired");
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateUser({
    required int userId,
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? imageBase64,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        "userName": username,
        "firstName": firstName,
        "lastName": lastName,
        "email": email,
        "password": password,
      };
      if (imageBase64 != null) {
        requestBody["image"] = imageBase64;
      }
      final response = await ApiService().put(
        '/users/$userId',
        jsonEncode(requestBody),
      );
      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication expired");
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteUser(int userId) async {
    try {
      final response = await ApiService().delete('/users/$userId');
      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication expired");
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<InventoryItem>> searchItemsByName({
    required int userId,
    required String name,
  }) async {
    try {
      final response = await ApiService()
          .get('/users/$userId/items/searchByName?name=$name');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => InventoryItem.fromJson(item)).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Authentication expired");
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static Future<List<InventoryItem>> filterItems({
    required int userId,
    String? name,
    DateTime? createdBefore,
    DateTime? createdAfter,
    int? lendingStatus,
    String? locationName,
    String? description,
    String? attributeName,
    String? attributeValue,
    String? quantity,
    String? quantityMoreThan,
    String? quantityLessThan,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {};
      if (name != null) requestBody['name'] = name;
      if (createdBefore != null) {
        requestBody['createdBefore'] = createdBefore.toUtc().toIso8601String();
      }
      if (createdAfter != null) {
        requestBody['createdAfter'] = createdAfter.toUtc().toIso8601String();
      }
      if (lendingStatus != null) requestBody['lendingStatus'] = lendingStatus;
      if (locationName != null) requestBody['locationName'] = locationName;
      if (description != null) requestBody['description'] = description;
      if (attributeName != null) requestBody['attributeName'] = attributeName;
      if (attributeValue != null) requestBody['attributeValue'] = attributeValue;

      // Add new quantity filter parameters
      if (quantity != null) requestBody['quantity'] = quantity;
      if (quantityMoreThan != null) requestBody['quantityMoreThan'] = quantityMoreThan;
      if (quantityLessThan != null) requestBody['quantityLessThan'] = quantityLessThan;

      final response = await ApiService().post(
        '/users/$userId/items/filter',
        json.encode(requestBody),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => InventoryItem.fromJson(item)).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Authentication expired");
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static String extractMessage(String input, String keyword) {
    final index = input.indexOf(keyword);
    if (index != -1) {
      return input.substring(index).trim();
    }
    return input;
  }
}
