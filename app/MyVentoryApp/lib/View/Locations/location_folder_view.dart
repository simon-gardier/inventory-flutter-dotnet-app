import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/location.dart';
import 'package:my_ventory_mobile/Controller/location_controller.dart';

class LocationFolderView extends StatefulWidget {
  final List<Location> locations;
  final Function(Location) onLocationSelected;

  const LocationFolderView({
    super.key,
    required this.locations,
    required this.onLocationSelected,
  });

  @override
  State<LocationFolderView> createState() => _LocationFolderViewState();
}

class _LocationFolderViewState extends State<LocationFolderView> {
  // Variables
  final Map<int, Uint8List?> locationImages = {};

  @override
  void initState() {
    super.initState();
    loadLocationImages();
  }

  @override

  // ==========================================================================
  // Check if locations have changed, reload images if needed
  void didUpdateWidget(LocationFolderView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.locations != oldWidget.locations) {
      loadLocationImages();
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Load first image for each location to serve as background for the widget
  Future<void> loadLocationImages() async {
    for (var location in widget.locations) {
      try {
        final images =
            await LocationController.getLocationImages(location.locationId);
        if (images != null && images.isNotEmpty) {
          try {
            final String imageBinString = images.first.imageBin ?? '';
            if (imageBinString.isNotEmpty) {
              final imageBytes = base64Decode(imageBinString);
              setState(() {
                locationImages[location.locationId] = imageBytes;
              });
            }
          } catch (e) {
            locationImages[location.locationId] = null;
          }
        } else {
          locationImages[location.locationId] = null;
        }
      } catch (e) {
        locationImages[location.locationId] = null;
      }
    }
  }
  // ==========================================================================

  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (widget.locations.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.locations.length,
      itemBuilder: (context, index) => buildFolderItem(widget.locations[index]),
    );
  }
  // ==========================================================================

  // ==========================================================================
  // Get cached image for this location if available
  Widget buildFolderItem(Location location) {
    final imageBytes = locationImages[location.locationId];
    const Color folderColor = Color(0xFFD4E8D1);

    return InkWell(
      onTap: () => widget.onLocationSelected(location),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withAlpha(76),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            if (imageBytes != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.2),
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),

            // Folder content (icon and text)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder,
                    size: 40,
                    color: folderColor,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            location.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Free space: ${location.capacity - location.usedCapacity}/${location.capacity}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                            fontWeight: FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
