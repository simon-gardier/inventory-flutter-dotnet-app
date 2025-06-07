class InventoryItem {
  final int itemId;
  final String name;
  final int quantity;
  final String description;
  final int ownerId;
  final String ownerName;
  final String? ownerEmail;
  final int? lendingState;
  final String? location;
  final int? locationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ItemImage>? images;
  final String? borrowedFrom;
  final DateTime? dueDate;
  final List<ItemAttribute>? attributes;

  InventoryItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.description,
    required this.ownerId,
    required this.ownerName,
    this.ownerEmail,
    this.lendingState,
    this.location,
    this.locationId,
    required this.createdAt,
    required this.updatedAt,
    this.images,
    this.borrowedFrom,
    this.dueDate,
    this.attributes,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      itemId: json["itemId"] ?? -1,
      name: json["name"] ?? "Unnamed Item",
      quantity: json["quantity"] ?? 0,
      description: json["description"] ?? "No description",
      ownerId: json["ownerId"] ?? -1,
      ownerName: json["ownerName"] ?? "Unknown",
      ownerEmail: json["ownerEmail"],
      lendingState: json["lendingState"],
      location: json["location"],
      locationId: json["locationId"],
      createdAt: json["createdAt"] != null
          ? DateTime.parse(json["createdAt"])
          : DateTime.now(),
      updatedAt: json["updatedAt"] != null
          ? DateTime.parse(json["updatedAt"])
          : DateTime.now(),
      images: json["images"] != null
          ? (json["images"] as List)
              .map((img) => ItemImage.fromJson(img))
              .toList()
          : null,
      borrowedFrom: json["borrowedFrom"],
      dueDate: json["dueDate"] != null ? DateTime.parse(json["dueDate"]) : null,
      attributes: json["attributes"] != null
          ? (json["attributes"] as List)
              .map((attr) => ItemAttribute.fromJson(attr))
              .toList()
          : null,
    );
  }

  factory InventoryItem.fromExternalJson(Map<String, dynamic> json) {
    return InventoryItem(
      itemId: json["itemId"] ?? -1,
      name: json["name"] ?? "Unnamed Item",
      quantity: json["quantity"] ?? 0,
      description: json["description"] ?? "No description",
      ownerName: json["ownerName"] ?? "Unknown",
      ownerEmail: json["ownerEmail"],
      ownerId: json["owner"]?["userId"] ?? json["id"] ?? -1,
      locationId: json["locationId"],
      createdAt: json["createdAt"] != null
          ? DateTime.parse(json["createdAt"])
          : DateTime.now(),
      updatedAt: json["updatedAt"] != null
          ? DateTime.parse(json["updatedAt"])
          : DateTime.now(),
      images: json["imageURL"] != null
          ? [ItemImage.fromExternalJson(json["itemId"] ?? -1, json["imageURL"])]
          : null,
      // images: json["images"] != null
      //       ? (json["images"] as List).map((img) => ItemImage.fromJson(img)).toList()
      //       : json["image"] != null
      //       ? [ItemImage.fromExternalJson(json["itemId"] ?? -1, json["image"])]
      //       : null,
      borrowedFrom: json["borrowedFrom"] ?? "Not borrowed",
      dueDate: json["dueDate"] != null ? DateTime.parse(json["dueDate"]) : null,
      attributes: json["attributes"] != null
          ? (json["attributes"] as List)
              .map((attr) => ItemAttribute.fromExternalJson(attr))
              .toList()
          : null,
    );
  }

  InventoryItem copyWith({
    int? itemId,
    String? name,
    int? quantity,
    String? description,
    int? ownerId,
    String? ownerName,
    int? lendingState,
    String? location,
    int? locationId,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ItemImage>? images,
    String? borrowedFrom,
    DateTime? dueDate,
    List<ItemAttribute>? attributes,
  }) {
    return InventoryItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      lendingState: lendingState ?? this.lendingState,
      location: location ?? this.location,
      locationId: locationId ?? this.locationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      borrowedFrom: borrowedFrom ?? this.borrowedFrom,
      dueDate: dueDate ?? this.dueDate,
      attributes: attributes ?? this.attributes,
    );
  }
}

class ItemImage {
  final int imageId;
  final int itemId;
  final String imageBin;

  ItemImage({
    required this.imageId,
    required this.itemId,
    required this.imageBin,
  });

  factory ItemImage.fromJson(Map<String, dynamic> json) {
    return ItemImage(
      imageId: json["imageId"],
      itemId: json["itemId"],
      imageBin: json["imageData"],
    );
  }

  factory ItemImage.fromExternalJson(int item, String image) {
    return ItemImage(
      imageId: -1,
      itemId: item,
      imageBin: image,
    );
  }
}

class ItemAttribute {
  final int attributeId;
  final String value;
  final String name;
  final String type;

  ItemAttribute({
    required this.attributeId,
    required this.value,
    required this.name,
    required this.type,
  });

  factory ItemAttribute.fromJson(Map<String, dynamic> json) {
    return ItemAttribute(
      attributeId: json["attributeId"],
      value: json["value"],
      name: json["name"],
      type: json["type"],
    );
  }

  factory ItemAttribute.fromExternalJson(Map<String, dynamic> json) {
    String returnType = '';
    if (json["type"] == "string") {
      returnType = "Text";
    } else {
      returnType = json["type"];
    }
    return ItemAttribute(
      attributeId: -1,
      value: json["value"],
      name: json["name"],
      type: returnType,
    );
  }
}

class ItemLending {
  final int transactionId;
  final int itemId;
  final int quantity;

  ItemLending({
    required this.transactionId,
    required this.itemId,
    required this.quantity,
  });
}

class ItemLocation {
  final int itemId;
  final int locationId;
  final DateTime assignmentDate;

  ItemLocation({
    required this.itemId,
    required this.locationId,
    required this.assignmentDate,
  });

  factory ItemLocation.fromJson(Map<String, dynamic> json) {
    return ItemLocation(
      itemId: json["itemId"],
      locationId: json["locationId"],
      assignmentDate: DateTime.parse(json["assignmentDate"]),
    );
  }
}

class ItemUserGroup {
  final int itemId;
  final int groupId;

  ItemUserGroup({
    required this.itemId,
    required this.groupId,
  });
}
