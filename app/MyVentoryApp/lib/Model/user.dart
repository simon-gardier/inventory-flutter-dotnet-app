import '../Model/item.dart';
import '../Model/location.dart';
import '../Model/lending.dart';

class UserAccount {
  final int userId;
  final String userName;
  final String firstName;
  final String lastName;
  final String email;
  final String passwordHash;
  final String? profilePicture;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<InventoryItem>? ownedItems;
  final List<Location>? ownedLocations;
  final List<UserGroupMembership>? groupMemberships;
  final List<Lending>? borrowedItems;
  final List<Lending>? lentItems;

  UserAccount({
    required this.userId,
    required this.userName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.passwordHash,
    this.profilePicture,
    required this.createdAt,
    required this.updatedAt,
    this.ownedItems,
    this.ownedLocations,
    this.groupMemberships,
    this.borrowedItems,
    this.lentItems,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      userId: json["userId"]?.toInt() ?? -1, // Default to -1 if null
      userName: json["userName"]?.toString() ??
          "Unknown", // Default to "Unknown" if null
      firstName:
          json["firstName"]?.toString() ?? "", // Default to empty if null
      lastName: json["lastName"]?.toString() ?? "", // Default to empty if null
      email: json["email"]?.toString() ??
          "No email", // Default to "No email" if null
      passwordHash:
          json["passwordHash"]?.toString() ?? "", // Default to empty if null
      profilePicture: json["profilePicture"]
          ?.toString(), // Allow null but convert to String if not null
      createdAt: json["createdAt"] != null
          ? DateTime.parse(json["createdAt"])
          : DateTime.now(), // Default to now if null
      updatedAt: json["updatedAt"] != null
          ? DateTime.parse(json["updatedAt"])
          : DateTime.now(), // Default to now if null
      ownedItems: json["ownedItems"] != null
          ? (json["ownedItems"] as List<dynamic>)
              .map((item) => InventoryItem.fromJson(item))
              .toList()
          : null,
      ownedLocations: json["ownedLocations"] != null
          ? (json["ownedLocations"] as List<dynamic>)
              .map((location) => Location.fromJson(location))
              .toList()
          : null,
      groupMemberships: json["groupMemberships"] != null
          ? (json["groupMemberships"] as List<dynamic>)
              .map((group) => UserGroupMembership.fromJson(group))
              .toList()
          : null,
      borrowedItems: json["borrowedItems"] != null
          ? (json["borrowedItems"] as List<dynamic>)
              .map((lending) => Lending.fromJson(lending))
              .toList()
          : null,
      lentItems: json["lentItems"] != null
          ? (json["lentItems"] as List<dynamic>)
              .map((lending) => Lending.fromJson(lending))
              .toList()
          : null,
    );
  }
}

class UserGroup {
  final int groupId;
  final String name;
  final String description;
  final String privacy;
  final String? groupPicture;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserGroup({
    required this.groupId,
    required this.name,
    required this.description,
    required this.privacy,
    this.groupPicture,
    required this.createdAt,
    required this.updatedAt,
  });
}

class UserGroupMembership {
  final int userId;
  final int groupId;
  final String role;

  UserGroupMembership({
    required this.userId,
    required this.groupId,
    required this.role,
  });

  factory UserGroupMembership.fromJson(Map<String, dynamic> json) {
    return UserGroupMembership(
      userId: json["userId"],
      groupId: json["groupId"],
      role: json["role"],
    );
  }
}
