import 'dart:io';
import 'dart:typed_data';
import 'package:my_ventory_mobile/Model/group.dart';
import 'package:my_ventory_mobile/API_authorizations/group_api_service.dart';

class GroupController {
  final GroupApiService _apiService = GroupApiService();

  Future<List<Group>> getMyGroups(int userId) async {
    return await _apiService.getMyGroups(userId);
  }

  Future<List<Group>> getPublicGroups() async {
    return await _apiService.getPublicGroups();
  }

  Future<Group> getGroupById(int groupId) async {
    return await _apiService.getGroupById(groupId);
  }

  Future<Group> addMemberToGroup(
      int groupId, int userId, MemberRole role) async {
    return await _apiService.addMemberToGroup(groupId, userId, role);
  }

  Future<bool> removeMemberFromGroup(int groupId, int userId) async {
    return await _apiService.removeMemberFromGroup(groupId, userId);
  }

  Future<bool> joinGroup(int userId, int groupId) async {
    return await _apiService.joinGroup(groupId);
  }

  Future<bool> leaveGroup(int userId, int groupId) async {
    return await _apiService.leaveGroup(groupId);
  }

  Future<Group> createGroup({
    required String name,
    required GroupPrivacy privacy,
    String? description,
    File? groupProfilePicture,
  }) async {
    return await _apiService.createGroup(
      name: name,
      privacy: privacy,
      description: description,
      groupProfilePicture: groupProfilePicture,
    );
  }

  Future<Group> updateGroup({
    required int groupId,
    String? name,
    GroupPrivacy? privacy,
    String? description,
    File? groupProfilePicture,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    return await _apiService.updateGroup(
      groupId: groupId,
      name: name,
      privacy: privacy,
      description: description,
      groupProfilePicture: groupProfilePicture,
      imageBytes: imageBytes,
      imageName: imageName,
    );
  }

  Future<bool> deleteGroup(int groupId) async {
    return await _apiService.deleteGroup(groupId);
  }

  Future<List<Group>> searchGroups({
    String? name,
    String? description,
    bool? isPublic,
    int? ownerId,
    String? sortBy,
    bool? ascending,
  }) async {
    // This would be implemented with a real API call when available
    throw Exception('Search API not implemented yet');
  }
}
