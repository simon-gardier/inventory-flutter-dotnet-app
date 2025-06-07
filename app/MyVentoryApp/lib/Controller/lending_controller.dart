import 'package:my_ventory_mobile/Config/config.dart';
import 'dart:convert';
import '../Model/lending.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';

class LendingController {
  static const String apiUrl = "${AppConfig.apiBaseUrl}/lendings";

  static Future<Lending?> getLendingById(int transactionId) async {
    try {
      final response = await ApiService().get('/lendings/$transactionId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Lending(
          transactionId: data["transactionId"],
          borrowerId: data["borrowerId"],
          borrowerName: data["borrowerName"],
          lenderId: data["lenderId"],
          dueDate: DateTime.parse(data["dueDate"]),
          lendingDate: DateTime.parse(data["lendingDate"]),
          lender: data["lender"],
          lenderName: data["lenderName"],
        );
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      }
      return null;
    } catch (e) {
      throw Exception("Failed to get lending: $e");
    }
  }

  static Future<bool> endLending(int transactionId) async {
    try {
      final response =
          await ApiService().put('/lendings/$transactionId/end', null);

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      }
      return false;
    } catch (e) {
      throw Exception("Failed to end lending: $e");
    }
  }

  static Future<List<Lending>> getUserLendings(int userId) async {
    try {
      final response =
          await ApiService().get('/lendings/user/$userId/lendings');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Lending.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      }
      return [];
    } catch (e) {
      throw Exception("Failed to get user lendings: $e");
    }
  }

  static Future<List<Lending>> getUserBorrowings(int userId) async {
    try {
      final response =
          await ApiService().get('/lendings/user/$userId/borrowings');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Lending.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Authentication failed");
      }
      return [];
    } catch (e) {
      throw Exception("Failed to get user borrowings: $e");
    }
  }
}
