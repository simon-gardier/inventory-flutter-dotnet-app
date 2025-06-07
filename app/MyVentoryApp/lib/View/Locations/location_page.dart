import 'dart:convert';
import 'dart:typed_data'; // Keep for image decoding
import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Controller/location_controller.dart';
import 'package:my_ventory_mobile/Model/location.dart';
import 'package:my_ventory_mobile/View/Locations/location_edit_page.dart';

class LocationPage extends StatefulWidget {
  final int locationId;

  const LocationPage({
    super.key,
    required this.locationId,
  });

  @override
  LocationPageState createState() => LocationPageState();
}

class LocationPageState extends State<LocationPage> {
  // Variables
  bool isLoading = true;
  bool isEditing = false;
  Location? location;
  List<LocationImage> images = [];
  bool saveButtonPressed = false;

  @override
  void initState() {
    super.initState();
    loadLocationData();
  }

  // ==========================================================================
  // Loads location details and images
  Future<void> loadLocationData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      final locationData =
          await LocationController.getLocationById(widget.locationId);

      List<LocationImage> locationImages = [];
      if (locationData != null) {
        locationImages =
            await LocationController.getLocationImages(widget.locationId) ?? [];
      }

      if (!mounted) return;

      setState(() {
        location = locationData;
        images = locationImages;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading location: $e")),
        );
      }
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Method to handle save button press from app bar
  bool getAppBarSaveState() {
    final state = saveButtonPressed;
    // Reset immediately after reading
    if (state) {
      saveButtonPressed = false;
    }
    return state;
  }
  // ==========================================================================

  // ==========================================================================
  // Method to handle completion of editing
  void handleEditingComplete() {
    if (mounted) {
      setState(() {
        isEditing = false;
      });
      loadLocationData();
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Method to cancel editing
  void handleEditingCancel() {
    // Check if mounted before setting state
    if (mounted) {
      setState(() {
        isEditing = false;
      });
      // Optionally reload data if you want to discard any visual changes made in edit mode
      // _loadLocationData();
    }
  }
  // ==========================================================================

  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 87, 143, 134),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 87, 143, 134),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        title: Text(
          isEditing ? "Edit Location" : (location?.name ?? "Location Details"),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (isEditing) {
              handleEditingCancel();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              tooltip: 'Save Changes',
              onPressed: () {
                if (mounted) {
                  setState(() {
                    saveButtonPressed = true;
                  });
                }
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit Location',
              onPressed: () {
                if (mounted) {
                  setState(() {
                    isEditing = true;
                  });
                }
              },
            ),
          if (!isEditing && location != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Delete Location',
              onPressed: confirmDeleteLocation,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : isEditing
              ? LocationEditPage(
                  locationId: widget.locationId,
                  onSave: handleEditingComplete,
                  onCancel: handleEditingCancel,
                  appBarSaveCallback: getAppBarSaveState,
                )
              : buildLocationDetailsView(),
    );
  }
  // ==========================================================================

  // ==========================================================================
  // Confirmation dialog for deletion
  Future<void> confirmDeleteLocation() async {
    if (location == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Delete Location"),
          content: Text(
              "Are you sure you want to delete '${location!.name}'? This action cannot be undone."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _deleteLocation();
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Method to handle deletion Logic
  Future<void> _deleteLocation() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      bool success = await LocationController.deleteLocation(widget.locationId);
      if (!mounted) return; // Check again after await

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Location deleted successfully"),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to delete location"),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Error deleting location: $e"),
            backgroundColor: Colors.red),
      );
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Builder for displaying the location details
  Widget buildLocationDetailsView() {
    if (location == null) {
      return const Center(
          child: Text("Location not found",
              style: TextStyle(color: Colors.white)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty) ...[
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  try {
                    final String imageBinString = images[index].imageBin ?? '';
                    if (imageBinString.isEmpty) {
                      return buildImagePlaceholder();
                    }
                    Uint8List imageBytes = base64Decode(imageBinString);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.memory(
                          imageBytes,
                          height: 200,
                          width: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => buildImagePlaceholder(),
                        ),
                      ),
                    );
                  } catch (e) {
                    return buildImagePlaceholder();
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            buildImagePlaceholder(isGalleryEmpty: true),
            const SizedBox(height: 24),
          ],
          Card(
            elevation: 2,
            color: Colors.white.withAlpha(26),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Location Details",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                  const Divider(color: Colors.white30),
                  const SizedBox(height: 8),
                  buildDetailRow(Icons.label_outline, "Name", location!.name),
                  const SizedBox(height: 16),
                  buildDetailRow(Icons.inventory_2_outlined, "Capacity",
                      "${location!.capacity}"),
                  const SizedBox(height: 16),
                  if (location!.description != null &&
                      location!.description!.isNotEmpty) ...[
                    buildDetailRow(Icons.description_outlined, "Description",
                        location!.description!),
                    const SizedBox(height: 16),
                  ],
                  FutureBuilder<Location?>(
                    future: location!.parentLocationId != null
                        ? LocationController.getLocationById(
                            location!.parentLocationId!)
                        : Future.value(null),
                    builder: (context, snapshot) {
                      String parentName = "None";
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        parentName = "Loading...";
                      } else if (snapshot.hasData && snapshot.data != null) {
                        parentName = snapshot.data!.name;
                      }
                      return buildDetailRow(
                          Icons.folder_outlined, "Parent Location", parentName);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Sublocations",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Location>?>(
            future: LocationController.getSublocations(widget.locationId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }

              final sublocations = snapshot.data ?? [];

              if (sublocations.isEmpty) {
                return Card(
                  color: Colors.white.withAlpha(26),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text("No sublocations",
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sublocations.length,
                itemBuilder: (context, index) {
                  final sublocation = sublocations[index];
                  return Card(
                    color: Colors.white.withAlpha(26),
                    child: ListTile(
                      leading: const Icon(Icons.folder, color: Colors.white70),
                      title: Text(sublocation.name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text("Capacity: ${sublocation.capacity}",
                          style: const TextStyle(color: Colors.white60)),
                      onTap: () {
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LocationPage(
                              locationId: sublocation.locationId,
                            ),
                          ),
                        ).then((_) {
                          if (mounted) {
                            loadLocationData();
                          }
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  // ==========================================================================

  // ==========================================================================
  // Method to build a widget that displays details row
  Widget buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
  // ==========================================================================

  // ==========================================================================
  // Method to build a widget for image placeholders
  Widget buildImagePlaceholder({bool isGalleryEmpty = false}) {
    return Container(
      height: 200,
      width: isGalleryEmpty ? double.infinity : 200,
      margin: isGalleryEmpty ? null : const EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
          color: Colors.white.withAlpha(13),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.white12)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                isGalleryEmpty
                    ? Icons.image_not_supported_outlined
                    : Icons.broken_image_outlined,
                size: 50,
                color: Colors.white30),
            if (isGalleryEmpty) ...[
              const SizedBox(height: 8),
              const Text("No images", style: TextStyle(color: Colors.white30))
            ]
          ],
        ),
      ),
    );
  }
// ==========================================================================
}
