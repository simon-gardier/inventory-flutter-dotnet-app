import 'dart:convert';
import 'dart:typed_data';

enum GroupPrivacy { public, private }

enum MemberRole { founder, administrator, member }

class Group {
  final int groupId;
  final String name;
  final GroupPrivacy privacy;
  final String description;
  final Uint8List? groupProfilePicture;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GroupMember> members;

  Group({
    required this.groupId,
    required this.name,
    required this.privacy,
    required this.description,
    this.groupProfilePicture,
    required this.createdAt,
    required this.updatedAt,
    required this.members,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    List<dynamic> membersList = json['members'] ?? json['Members'] ?? [];
    return Group(
      groupId: json['groupId'] ?? json['GroupId'],
      name: json['name'] ?? json['Name'],
      privacy: (json['privacy'] ?? json['Privacy']) == 0
          ? GroupPrivacy.public
          : GroupPrivacy.private,
      description: json['description'] ?? json['Description'] ?? '',
      groupProfilePicture: json['groupProfilePicture'] != null
          ? base64Decode(json['groupProfilePicture'])
          : json['GroupProfilePicture'] != null
              ? base64Decode(json['GroupProfilePicture'])
              : null,
      createdAt: DateTime.parse(json['createdAt'] ?? json['CreatedAt']),
      updatedAt: DateTime.parse(json['updatedAt'] ?? json['UpdatedAt']),
      members:
          membersList.map((member) => GroupMember.fromJson(member)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'name': name,
      'privacy': privacy == GroupPrivacy.public ? 0 : 1,
      'description': description,
      'groupProfilePicture': groupProfilePicture != null
          ? base64Encode(groupProfilePicture!)
          : null,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'members': members.map((member) => member.toJson()).toList(),
    };
  }

  bool get isPublic => privacy == GroupPrivacy.public;

  bool isUserMember(int userId) {
    return members.any((member) => member.userId == userId);
  }

  bool isUserFounder(int userId) {
    return members.any((member) =>
        member.userId == userId && member.role == MemberRole.founder);
  }

  bool isUserAdmin(int userId) {
    return members.any((member) =>
        member.userId == userId &&
        (member.role == MemberRole.administrator ||
            member.role == MemberRole.founder));
  }
}

class GroupMember {
  final int userId;
  final String username;
  final String firstName;
  final String lastName;
  final MemberRole role;

  GroupMember({
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    MemberRole role;
    final roleValue = json['role'] ?? json['Role'];

    if (roleValue is int) {
      switch (roleValue) {
        case 0:
          role = MemberRole.founder;
          break;
        case 1:
          role = MemberRole.administrator;
          break;
        default:
          role = MemberRole.member;
      }
    } else {
      switch (roleValue) {
        case 'Founder':
          role = MemberRole.founder;
          break;
        case 'Administrator':
          role = MemberRole.administrator;
          break;
        default:
          role = MemberRole.member;
      }
    }

    return GroupMember(
      userId: json['userId'] ?? json['UserId'],
      username: json['username'] ?? json['Username'],
      firstName: json['firstName'] ?? json['FirstName'],
      lastName: json['lastName'] ?? json['LastName'],
      role: role,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'role': role == MemberRole.founder
          ? 0
          : role == MemberRole.administrator
              ? 1
              : 2,
    };
  }

  String get fullName => '$firstName $lastName';
  bool get isFounder => role == MemberRole.founder;
  bool get isAdmin =>
      role == MemberRole.administrator || role == MemberRole.founder;
}
