import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../Model/item.dart';
import '../Config/config.dart';
import 'package:mime/mime.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';

class ItemController {
  static const String apiUrl = "${AppConfig.apiBaseUrl}/items";
  // static String get apiUrl => "${AppConfig.apiBaseUrl}/items";

  // Add a cache for borrowed items to avoid unnecessary API calls
  static final Map<int, InventoryItem> _borrowedItemsCache = {};

  // Method to store borrowed items in cache
  static void cacheBorrowedItem(InventoryItem item) {
    _borrowedItemsCache[item.itemId] = item;
  }

  // Method to check if an item is in the borrowed items cache
  static bool isBorrowedItemCached(int itemId) {
    return _borrowedItemsCache.containsKey(itemId);
  }

  // Method to get a borrowed item from cache
  static InventoryItem? getCachedBorrowedItem(int itemId) {
    return _borrowedItemsCache[itemId];
  }

  // Method to clear a specific item from cache
  static void clearCachedItem(int itemId) {
    _borrowedItemsCache.remove(itemId);
  }

  // Method to clear all cached borrowed items
  static void clearBorrowedItemsCache() {
    _borrowedItemsCache.clear();
  }

  static Future<InventoryItem?> createItem({
    required String name,
    required int quantity,
    required String description,
    required int ownerId,
  }) async {
    try {
      final response = await ApiService().post(
        '/items',
        jsonEncode({
          "Name": name,
          "Quantity": quantity,
          "Description": description,
          "OwnerId": ownerId
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return InventoryItem.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else {
        return null;
      }
    } catch (e) {
      throw Exception("Failed to create item: $e");
    }
  }

  static Future<bool> deleteItem(int itemId) async {
    try {
      final response = await ApiService().delete(
        '/items/$itemId',
      );

      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Item not found.");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        throw Exception(
            "Failed to delete item. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to delete item: $e");
    }
  }

  static Future<bool> addItemImage({
    required int itemId,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    try {
      String endOfFilename;
      if (filename.startsWith('http://') || filename.startsWith('https://')) {
        endOfFilename = Uri.parse(filename).pathSegments.last;
      } else {
        endOfFilename = filename.split('/').last;
      }

      final String? mimeType = lookupMimeType(endOfFilename);
      final MediaType contentType;
      if (mimeType != null &&
          (mimeType == 'image/jpeg' || mimeType == 'image/png')) {
        final parts = mimeType.split('/');
        contentType = MediaType(parts[0], parts[1]);
      } else {
        contentType = MediaType('image', 'jpeg');
      }

      final imageFile = http.MultipartFile.fromBytes(
        'images',
        imageBytes,
        filename: filename,
        contentType: contentType,
      );

      final response = await ApiService().multipartPost(
        '/items/$itemId/image',
        {},
        [imageFile],
      );

      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
    } catch (e) {
      throw Exception("Failed to add item image: $e");
    }
  }

  static Future<List<ItemImage>?> getItemImages(int itemId) async {
    try {
      // Check if this is a cached borrowed item with images
      if (_borrowedItemsCache.containsKey(itemId) &&
          _borrowedItemsCache[itemId]!.images != null &&
          _borrowedItemsCache[itemId]!.images!.isNotEmpty) {
        return _borrowedItemsCache[itemId]!.images;
      }

      final response = await ApiService().get('/items/$itemId/images');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ItemImage.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<bool> removeItemImage({
    required int itemId,
    required List<int> imageIds,
  }) async {
    if (imageIds.isEmpty) {
      return true;
    }

    try {
      final response = await ApiService().delete(
        '/items/$itemId/image',
        body: jsonEncode(imageIds),
      );
      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Item not found, or one or more images not found.");
      } else if (response.statusCode == 400) {
        throw Exception(
            "Bad Request: Invalid image IDs provided. Details: ${response.body}");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        throw Exception(
            "Failed to delete images. Status code: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      throw Exception("Failed to remove item images: $e");
    }
  }

  static Future<bool> addItemAttributes({
    required int itemId,
    required List<Map<String, String>> attributes,
  }) async {
    try {
      final response = await ApiService().post(
        '/items/$itemId/attributes',
        jsonEncode(attributes),
      );

      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 400) {
        throw Exception("Bad Request: Invalid data provided.");
      } else if (response.statusCode == 404) {
        throw Exception("Not Found: Item does not exist.");
      } else if (response.statusCode == 500) {
        throw Exception("Server Error: Please try again later.");
      } else {
        throw Exception(
            "Failed to add attributes. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to add item attributes: $e");
    }
  }

  static Future<List<ItemAttribute>> getAttributesForItem(int itemId) async {
    try {
      // Check if this is a cached borrowed item with attributes
      if (_borrowedItemsCache.containsKey(itemId) &&
          _borrowedItemsCache[itemId]!.attributes != null &&
          _borrowedItemsCache[itemId]!.attributes!.isNotEmpty) {
        return _borrowedItemsCache[itemId]!.attributes!;
      }

      final response = await ApiService().get('/items/$itemId/attributes');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => ItemAttribute.fromJson(item)).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Item not found");
      } else {
        throw Exception("Failed to load attributes");
      }
    } catch (e) {
      throw Exception("Failed to get attributes: $e");
    }
  }

  static Future<InventoryItem?> getItemById(int itemId) async {
    try {
      // Check if this is a cached borrowed item
      if (_borrowedItemsCache.containsKey(itemId)) {
        return _borrowedItemsCache[itemId];
      }

      final response = await ApiService().get('/items/$itemId');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return InventoryItem.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Item not found.");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        throw Exception(
            "Failed to load item. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to get item: $e");
    }
  }

  static Future<bool> updateItem({
    required int itemId,
    String? newName,
    int? newQuantity,
    String? newDescription,
    int? ownerId,
    int? parentItemId,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {};
      if (newName != null) requestBody["name"] = newName;
      if (newQuantity != null) requestBody["quantity"] = newQuantity;
      if (newDescription != null) requestBody["description"] = newDescription;
      if (ownerId != null) requestBody["ownerId"] = ownerId;
      if (parentItemId != null) requestBody["parentItemId"] = parentItemId;

      if (requestBody.isEmpty) return false;

      final response = await ApiService().put(
        '/items/$itemId',
        jsonEncode(requestBody),
      );

      if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      }

      return response.statusCode == 204;
    } catch (e) {
      throw Exception("Failed to update item: $e");
    }
  }

  static Future<bool> removeItemAttribute({
    required int itemId,
    required int attributeId,
  }) async {
    try {
      final response = await ApiService().delete(
        '/items/$itemId/attributes',
        body: jsonEncode([attributeId]),
      );

      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      } else if (response.statusCode == 404) {
        throw Exception("Item or Attribute not found.");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        throw Exception(
            "Failed to remove attribute. Status code: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to remove attribute: $e");
    }
  }
}
