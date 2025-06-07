import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../Model/location.dart';
import '../Model/item.dart';
import '../Config/config.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';

class LocationController {
  static String get apiUrl => "${AppConfig.apiBaseUrl}/locations";

  static Future<Location?> createLocation({
    required String name,
    required int capacity,
    required String description,
    required int ownerId,
    int? parentLocationId,
    String? firstImage,
  }) async {
    try {
      final response = await ApiService().post(
        '/locations',
        jsonEncode({
          "name": name,
          "capacity": capacity,
          "description": description,
          "ownerId": ownerId,
          "parentLocationId": parentLocationId,
          "firstImage": firstImage,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Location.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 400) {
        throw Exception("Bad Request: Invalid data provided");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        return null;
      }
    } catch (e) {
      throw Exception("Failed to create location: $e");
    }
  }

  static Future<bool> moveItemToLocation({
    required int locationId,
    required int itemId,
  }) async {
    try {
      final response = await ApiService().post(
        '/locations/$locationId/items/$itemId',
        null,
      );

      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 400) {
        throw Exception("Bad Request: Invalid data provided");
      } else if (response.statusCode == 404) {
        throw Exception("Location or Item not found");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        return false;
      }
    } catch (e) {
      throw Exception("Failed to move item to location: $e");
    }
  }

  static Future<bool> deleteLocation(int locationId) async {
    try {
      final response = await ApiService().delete(
        '/locations/$locationId',
      );

      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Location not found.");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        throw Exception(
            "Failed to delete location. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to delete location: $e");
    }
  }

  static Future<Location?> updateLocation({
    required int locationId,
    required String name,
    required int capacity,
    required int ownerId,
    String? description,
    int? parentLocationId,
    String? firstImage,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        "name": name,
        "capacity": capacity,
        "ownerId": ownerId,
        "description": description,
        if (parentLocationId != null) "parentLocationId": parentLocationId,
        if (firstImage != null) "firstImage": firstImage,
      };

      final response = await ApiService().put(
        '/locations/$locationId',
        jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          try {
            final data = jsonDecode(response.body);
            return Location.fromJson(data);
          } catch (e) {
            throw Exception("API returned 200 OK but with invalid JSON body.");
          }
        } else {
          throw Exception("API returned 200 OK but with an empty body.");
        }
      } else if (response.statusCode == 204) {
        return await getLocationById(locationId);
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 400) {
        throw Exception(
            "Bad Request: Invalid data provided. Details: ${response.body}");
      } else if (response.statusCode == 404) {
        throw Exception("Location not found (404)");
      } else if (response.statusCode == 500) {
        throw Exception("Server error (500). Please try again later.");
      } else {
        throw Exception(
            "Failed to update location. Status: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to update location: $e");
    }
  }

  static Future<Location?> getLocationById(int locationId) async {
    try {
      final response = await ApiService().get('/locations/$locationId');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return Location.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Location not found.");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        throw Exception(
            "Failed to load location. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to get location: $e");
    }
  }

  static Future<bool> addLocationImage({
    required int locationId,
    required Uint8List imageBytes,
  }) async {
    try {
      final imageFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'image.jpg',
        contentType: MediaType('image', 'jpeg'),
      );

      final response = await ApiService().multipartPost(
        '/locations/$locationId/image',
        {},
        [imageFile],
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 400) {
        throw Exception("Bad Request: Invalid image data");
      } else if (response.statusCode == 404) {
        throw Exception("Location not found");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        return false;
      }
    } catch (e) {
      throw Exception("Failed to add location image: $e");
    }
  }

  static Future<bool> removeLocationImage({
    required int locationId,
    required int imageId,
  }) async {
    try {
      final response = await ApiService().delete(
        '/locations/$locationId/image/$imageId',
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Image or Location not found.");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        throw Exception(
            "Failed to delete image. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to remove location image: $e");
    }
  }

  static Future<List<LocationImage>?> getLocationImages(int locationId) async {
    try {
      final response = await ApiService().get('/locations/$locationId/images');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);
        List<LocationImage> images = [];

        for (int i = 0; i < responseData.length; i++) {
          // Checks if the item is a string or an object
          if (responseData[i] is String) {
            // Handles string format
            images.add(LocationImage(
              imageId: -1 - i,
              locationId: locationId,
              imageBin: responseData[i],
              location: null,
            ));
          } else if (responseData[i] is Map) {
            // Handle map format
            Map<String, dynamic> imageData = responseData[i];
            images.add(LocationImage(
              imageId: imageData['imageId'] ?? (-1 - i),
              locationId: locationId,
              imageBin: imageData['imageBin'],
              location: null,
            ));
          }
        }
        return images;
      } else if (response.statusCode == 500) {
        // Checks if this is the "no images" error
        try {
          final errorResponse = jsonDecode(response.body);
          if (errorResponse['detail'] == "Sequence contains no elements") {
            // This is actually just an empty result, not an error
            return [];
          }
        } catch (e) {
          // If we can't parse the error JSON, treats as a regular error
        }

        return [];
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Location not found");
      } else {
        return [];
      }
    } catch (e) {
      // Returns empty list instead of throwing exception to prevent app crashes
      return [];
    }
  }

  static Future<bool> removeItemFromLocation({
    required int locationId,
    required int itemId,
  }) async {
    try {
      final response = await ApiService().delete(
        '/locations/$locationId/items/$itemId',
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Item or Location not found.");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        throw Exception(
            "Failed to remove item from location. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to remove item from location: $e");
    }
  }

  static Future<List<InventoryItem>?> getItemsInLocation(int locationId) async {
    try {
      final response = await ApiService().get('/locations/$locationId/items');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => InventoryItem.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Location not found");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        return null;
      }
    } catch (e) {
      throw Exception("Failed to get items in location: $e");
    }
  }

  static Future<List<Location>?> getSublocations(int parentId) async {
    try {
      final response =
          await ApiService().get('/locations/$parentId/sublocations');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Location.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      // } else if (response.statusCode == 404) {
      //   throw Exception("Parent location not found");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        return null;
      }
    } catch (e) {
      throw Exception("Failed to get sublocations: $e");
    }
  }

  static Future<bool> updateParentLocation({
    required int locationId,
    required int parentLocationId,
  }) async {
    try {
      final response = await ApiService().put(
        '/locations/$locationId/parent/$parentLocationId',
        null,
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 400) {
        throw Exception("Bad Request: Invalid parent location");
      } else if (response.statusCode == 404) {
        throw Exception("Location or parent location not found");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        throw Exception(
            "Failed to update parent location. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to update parent location: $e");
    }
  }
}
