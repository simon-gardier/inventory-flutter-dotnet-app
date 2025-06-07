class Location {
  final int locationId;
  final String name;
  final int capacity;
  final int usedCapacity;
  final String? description;
  final int ownerId;
  final int? parentLocationId;
  final String? firstImage;

  Location({
    required this.locationId,
    required this.name,
    required this.capacity,
    required this.usedCapacity,
    this.description,
    required this.ownerId,
    this.parentLocationId,
    this.firstImage,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      locationId: json["locationId"],
      name: json["name"],
      capacity: json["capacity"],
      usedCapacity: json["usedCapacity"],
      description: json["description"],
      ownerId: json["ownerId"],
      parentLocationId: json["parentLocationId"],
      firstImage: json["firstImage"],
    );
  }

  // Method to create a new instance with updated values
  Location copyWith({
    int? locationId,
    String? name,
    int? capacity,
    int? usedCapacity,
    String? description,
    int? ownerId,
    int? parentLocationId,
    String? firstImage,
  }) {
    return Location(
      locationId: locationId ?? this.locationId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      usedCapacity: usedCapacity ?? this.usedCapacity,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      parentLocationId: parentLocationId, // Special case to allow null value
      firstImage: firstImage ?? this.firstImage,
    );
  }
}

class LocationImage {
  final int imageId;
  final int locationId;
  final String? imageBin;
  final String? location;

  LocationImage({
    required this.imageId,
    required this.locationId,
    this.imageBin,
    this.location,
  });

  factory LocationImage.fromJson(Map<String, dynamic> json) {
    return LocationImage(
      imageId: json["imageId"],
      locationId: json["locationId"],
      imageBin: json["imageBin"],
      location: json["location"],
    );
  }
}
