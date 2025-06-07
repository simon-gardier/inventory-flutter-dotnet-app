import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart'
    as api_service;

class ApiService {
  // Define all URL constants
  static const String externalSearchUrl = "/external";
  static const String generalScanUrl =
      "$externalSearchUrl/image"; // requestType == "GENERAL_IMAGE"
  static const String scanBarcodeUrl =
      "$externalSearchUrl/barcode?dummyResponse=false"; // requestType == "SCAN_BARCODE"
  static const String scanBookUrl =
      "$externalSearchUrl/books/image"; // requestType == "SCAN_BOOK"
  static const String authorTitleSearchUrl =
      "$externalSearchUrl/books/author_title"; // requestType == "SEARCH_AUTHOR_TITLE"
  static const String albumScanUrl =
      "$externalSearchUrl/albums/image"; // requestType == "SCAN_ALBUM"
  static const String albumSearchUrl =
      "$externalSearchUrl/albums/search"; // requestType == "SEARCH_ALBUM"

  Future<Map<String, dynamic>> searchExternalInventory({
    required String requestType,
    String? query,
    String? title,
    String? author,
    Uint8List? imageBytes,
    BuildContext? context,
  }) async {
    String q = '';

    if (query != null) q = '?&query=$query';

    String callUrl = '';
    if (requestType == "GENERAL_IMAGE") callUrl = generalScanUrl;
    if (requestType == "SCAN_BARCODE") callUrl = scanBarcodeUrl;
    if (requestType == "SCAN_BOOK") callUrl = scanBookUrl;
    if (requestType == "SEARCH_AUTHOR_TITLE") callUrl = authorTitleSearchUrl;
    if (requestType == "SCAN_ALBUM") callUrl = albumScanUrl;
    if (requestType == "SEARCH_ALBUM") callUrl = albumSearchUrl;

    final endpoint = '$callUrl$q';

    http.Response response;

    if (imageBytes != null) {
      final fields = <String, String>{};
      final files = <http.MultipartFile>[];

      final imageFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'image.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      files.add(imageFile);

      response = await api_service.ApiService().multipartPost(
        endpoint,
        fields,
        files,
        context: context,
      );
    } else {
      String? body;

      if (requestType == "SEARCH_AUTHOR_TITLE") {
        body = jsonEncode({'author': author ?? '', 'title': title ?? ''});
      }

      try {
        response = await api_service.ApiService().post(endpoint, body);
      } catch (e) {
        throw Exception('Error searching external inventory: $e');
      }
    }

    try {
      Map<String, dynamic> data = <String, dynamic>{};
      List<ItemAttribute> attributes = [];

      if (response.statusCode == 200 &&
          response.body != '{"message":"No book found in the response."}') {
        final Map<String, dynamic> responseData = json.decode(response.body);
        data['item'] = InventoryItem.fromExternalJson(responseData);
        if (responseData['attributes'] != null) {
          for (Map<String, dynamic> attr in responseData['attributes']) {
            attributes.add(ItemAttribute.fromExternalJson(attr));
          }
        }
        data['attributes'] = attributes;
        return data;
      } else {
        return {};
      }
    } catch (e) {
      throw Exception('Error searching external inventory: $e');
    }
  }
}
