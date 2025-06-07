import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'package:my_ventory_mobile/Model/group.dart';

class GroupApiService {
  final ApiService _apiService = ApiService();

  // Get all groups a user is a member of
  Future<List<Group>> getMyGroups(int userId) async {
    final response = await _apiService.get('/groups/user/$userId');
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((json) => Group.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load user groups: ${response.statusCode}');
    }
  }

  // Get all public groups
  Future<List<Group>> getPublicGroups() async {
    final response = await _apiService.get('/groups/public');
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((json) => Group.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load public groups: ${response.statusCode}');
    }
  }

  // Get details of a specific group
  Future<Group> getGroupById(int groupId) async {
    final response = await _apiService.get('/groups/$groupId');
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return Group.fromJson(jsonData);
    } else {
      throw Exception('Failed to load group: ${response.statusCode}');
    }
  }

  // Add a member to a group
  Future<Group> addMemberToGroup(
      int groupId, int userId, MemberRole role) async {
    final response = await _apiService.post(
      '/groups/$groupId/members',
      {
        'userId': userId,
        'role': role.toString().split('.').last.toLowerCase(),
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return Group.fromJson(jsonData);
    } else {
      throw Exception('Failed to add member: ${response.statusCode}');
    }
  }

  // Leave a group
  Future<bool> leaveGroup(int groupId) async {
    try {
      final response = await _apiService.delete('/groups/$groupId/leave');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        final errorMessage = response.body.isNotEmpty
            ? json.decode(response.body)['message'] ?? 'Failed to leave group'
            : 'Failed to leave group';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to leave group: ${e.toString()}');
    }
  }

  // Remove a member from a group (admin/founder action)
  Future<bool> removeMemberFromGroup(int groupId, int userId) async {
    try {
      final response =
          await _apiService.delete('/groups/$groupId/members/$userId');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        final errorMessage = response.body.isNotEmpty
            ? json.decode(response.body)['message'] ?? 'Failed to remove member'
            : 'Failed to remove member';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to remove member: ${e.toString()}');
    }
  }

  // Create a new group
  Future<Group> createGroup({
    required String name,
    required GroupPrivacy privacy,
    String? description,
    File? groupProfilePicture,
  }) async {
    final fields = {
      'Name': name,
      'Privacy': (privacy == GroupPrivacy.public ? 0 : 1).toString(),
    };
    if (description != null) {
      fields['Description'] = description;
    }
    final files = <http.MultipartFile>[];
    if (groupProfilePicture != null) {
      files.add(await http.MultipartFile.fromPath(
        'GroupProfilePicture',
        groupProfilePicture.path,
      ));
    }
    final response = await _apiService.multipartPost(
      '/groups',
      fields,
      files,
    );
    if (response.statusCode == 201) {
      final jsonData = json.decode(response.body);
      return Group.fromJson(jsonData);
    } else {
      throw Exception('Failed to create group: ${response.statusCode}');
    }
  }

  // Update a group
  Future<Group> updateGroup({
    required int groupId,
    String? name,
    GroupPrivacy? privacy,
    String? description,
    File? groupProfilePicture,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final fields = <String, String>{};
    if (name != null) fields['Name'] = name;
    if (privacy != null) fields['Privacy'] = privacy == GroupPrivacy.public ? 'Public' : 'Private';
    if (description != null) fields['Description'] = description;

    final files = <http.MultipartFile>[];
    if (groupProfilePicture != null) {
      if (imageBytes != null) {
        files.add(http.MultipartFile.fromBytes(
            'GroupProfilePicture', imageBytes,
            filename: imageName ?? 'image.jpeg',
            contentType: MediaType('image', 'jpeg')));
      } else {
        files.add(await http.MultipartFile.fromPath(
          'GroupProfilePicture',
          groupProfilePicture.path,
        ));
      }
    }

    final response = await _apiService.multipartPut(
      '/groups/$groupId',
      fields,
      files,
    );
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return Group.fromJson(jsonData);
    } else {
      throw Exception(
          'Failed to update group: ${response.statusCode} - ${response.body}');
    }
  }

  // Delete a group
  Future<bool> deleteGroup(int groupId) async {
    try {
      final response = await _apiService.delete('/groups/$groupId');
      if (response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Failed to delete group: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete group: ${e.toString()}');
    }
  }

  // Join a public group
  Future<bool> joinGroup(int groupId) async {
    try {
      final response = await _apiService.post(
        '/groups/$groupId/join',
        {},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        final errorMessage = response.body.isNotEmpty
            ? json.decode(response.body)['message'] ?? 'Failed to join group'
            : 'Failed to join group';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to join group: ${e.toString()}');
    }
  }

  // Check if API is available
  Future<bool> isApiAvailable() async {
    try {
      final response = await _apiService.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
