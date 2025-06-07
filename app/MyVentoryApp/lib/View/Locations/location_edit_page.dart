import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // <-- Import image_picker
import 'package:my_ventory_mobile/Controller/location_controller.dart';
import 'package:my_ventory_mobile/Controller/user_controller.dart';
import 'package:my_ventory_mobile/Model/clear_text_button.dart';
import 'package:my_ventory_mobile/Model/location.dart';
import 'package:my_ventory_mobile/Model/multiple_choice_button.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';

class LocationEditPage extends StatefulWidget {
  final int locationId;
  final Function onSave;
  final Function onCancel;
  final bool Function() appBarSaveCallback;

  const LocationEditPage({
    super.key,
    required this.locationId,
    required this.onSave,
    required this.onCancel,
    required this.appBarSaveCallback,
  });

  @override
  State<LocationEditPage> createState() => _LocationEditPageState();
}

class _LocationEditPageState extends State<LocationEditPage> {
  // Variables
  Location? location;
  bool isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final GlobalKey<TextBoxState> _nameKey = GlobalKey<TextBoxState>();
  final GlobalKey<TextBoxState> _capacityKey = GlobalKey<TextBoxState>();
  final GlobalKey<TextBoxState> _descriptionKey = GlobalKey<TextBoxState>();

  late ClearTextButton _nameClearButton;
  late ClearTextButton _capacityClearButton;
  late ClearTextButton _descriptionClearButton;

  String selectedParentLocation = "None";
  List<String> availableLocations = ["None"];
  Map<String, int> locationNameToId = {};

  // For image management
  final ImagePicker _picker = ImagePicker();
  List<File> newImages = [];
  List<LocationImage> existingImages = [];
  final List<int> _imageIdsToDelete = [];
  bool imageChanges = false;

  // Timer to periodically check if save was requested from app bar
  Timer? _saveCheckTimer;

  @override
  void initState() {
    super.initState();
    _nameClearButton =
        ClearTextButton(textBoxKey: _nameKey, boxC: _nameController);
    _capacityClearButton =
        ClearTextButton(textBoxKey: _capacityKey, boxC: _capacityController);
    _descriptionClearButton = ClearTextButton(
        textBoxKey: _descriptionKey, boxC: _descriptionController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        fetchAvailableLocations().then((_) {
          if (mounted) {
            loadLocationData();
          }
        });
      }
    });
    // Start a timer to periodically check if save was requested from app bar
    _saveCheckTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (mounted && widget.appBarSaveCallback()) {
        updateLocation();
      }
    });
  }

  @override
  void dispose() {
    _saveCheckTimer?.cancel();
    _nameController.dispose();
    _capacityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // Method to safely call setState only if the widget is mounted
  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Loads location data from API
  Future<void> loadLocationData() async {
    if (!mounted) return;
    setStateIfMounted(() {
      isLoading = true;
      _imageIdsToDelete.clear();
      newImages.clear();
      imageChanges = false;
    });

    Location? locationData;
    List<LocationImage> locationImages = [];

    try {
      locationData =
          await LocationController.getLocationById(widget.locationId);

      if (locationData != null) {
        try {
          locationImages =
              await LocationController.getLocationImages(widget.locationId) ??
                  [];
        } catch (e) {
          setStateIfMounted(() {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Could not load images: $e")),
            );
          });
        }
      }

      setStateIfMounted(() {
        if (locationData != null) {
          location = locationData;
          existingImages = locationImages;
          _nameController.text = locationData.name;
          _capacityController.text = locationData.capacity.toString();
          _descriptionController.text = locationData.description ?? '';
          isLoading = false;
          updateSelectedParentLocation();
        } else {
          isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location not found")),
          );
        }
      });
    } catch (e) {
      setStateIfMounted(() {
        isLoading = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load location: $e")),
        );
      });
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Method to set the selected parent location based on loaded data
  void updateSelectedParentLocation() {
    if (location == null || availableLocations.isEmpty) {
      selectedParentLocation = "None";
      return;
    }

    String parentName = "None";
    if (location!.parentLocationId != null) {
      parentName = locationNameToId.entries
          .firstWhere(
            (entry) => entry.value == location!.parentLocationId,
            orElse: () => const MapEntry("None", -1),
          )
          .key;
    }

    // Updates state only if the value needs changing and is valid
    if (selectedParentLocation != parentName &&
        availableLocations.contains(parentName)) {
      setStateIfMounted(() {
        selectedParentLocation = parentName;
      });
    } else if (!availableLocations.contains(parentName) &&
        selectedParentLocation != "None") {
      setStateIfMounted(() {
        selectedParentLocation = "None";
      });
    } else if (parentName == "None" && selectedParentLocation != "None") {
      setStateIfMounted(() {
        selectedParentLocation = "None";
      });
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Fetches available locations for parent selection
  Future<void> fetchAvailableLocations() async {
    List<Location> validParentLocations = [];
    Map<String, int> newLocationNameToId = {};
    List<String> newAvailableLocations = ["None"];

    try {
      int? loggedInUserId = await AuthService.getUserId();

      if (loggedInUserId == null) {
        setStateIfMounted(() {
          availableLocations = ["None"];
          locationNameToId = {};
        });
        return;
      }

      final allUserLocations =
          await UserController.getLocationsOfUser(loggedInUserId) ?? [];
      Set<int> descendantIds =
          await getDescendantLocationIds(widget.locationId, allUserLocations);
      descendantIds.add(widget.locationId);

      for (var l in allUserLocations) {
        // Excludes self and descendants
        if (!descendantIds.contains(l.locationId)) {
          validParentLocations.add(l);
        }
      }
      newAvailableLocations
          .addAll(validParentLocations.map((loc) => loc.name).toList());
      newLocationNameToId = {
        for (var l in validParentLocations) l.name: l.locationId
      };
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading parent locations: $e")),
        );
      }
    } finally {
      // Updates state after all async operations are done or failed
      setStateIfMounted(() {
        availableLocations = newAvailableLocations;
        locationNameToId = newLocationNameToId;
        updateSelectedParentLocation();
      });
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Recursive method to get all descendant IDs
  Future<Set<int>> getDescendantLocationIds(
      int parentId, List<Location> allLocations) async {
    Set<int> descendants = {};
    List<Location> directChildren =
        allLocations.where((loc) => loc.parentLocationId == parentId).toList();

    for (var child in directChildren) {
      descendants.add(child.locationId);
      descendants.addAll(
          await getDescendantLocationIds(child.locationId, allLocations));
    }
    return descendants;
  }
  // ==========================================================================

  // ==========================================================================
  // ---- Image Handling Methods ----

  // Method to show Camera/Gallery options
  Future<void> showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  takePictureWithCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Method to pick image(s) from the gallery
  Future<void> pickImageFromGallery() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty && mounted) {
        setStateIfMounted(() {
          for (var file in pickedFiles) {
            newImages.add(File(file.path));
          }
          imageChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  // Method to take pictures with the camera
  Future<void> takePictureWithCamera() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null && mounted) {
        setStateIfMounted(() {
          newImages.add(File(pickedFile.path));
          imageChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
    }
  }

  // Method to mark an existing image for deletion
  void deleteExistingImage(int imageId) {
    if (!_imageIdsToDelete.contains(imageId)) {
      setStateIfMounted(() {
        _imageIdsToDelete.add(imageId);
        imageChanges = true;
      });
    }
  }

  // Method to remove a newly added image before saving
  void removeNewImage(File imageFile) {
    setStateIfMounted(() {
      newImages.remove(imageFile);
      imageChanges = newImages.isNotEmpty || _imageIdsToDelete.isNotEmpty;
    });
  }
  // ==========================================================================

  // ==========================================================================
  // Parent location selection handler
  void _handleParentLocationChange(String value, int identifier) {
    setStateIfMounted(() {
      selectedParentLocation = value;
    });
  }
  // ==========================================================================

  // ==========================================================================
  // Method to update the location
  Future<void> updateLocation() async {
    if (isLoading || !mounted || location == null) return;

    setStateIfMounted(() {
      isLoading = true;
    });

    bool changesSuccessfullySaved = false;
    bool detailsUpdateAttempted = false;

    try {
      // ---  Delete marked images ---
      bool imageDeletionFailed = false;
      if (_imageIdsToDelete.isNotEmpty) {
        List<int> successfullyDeletedIds = [];
        List<int> failedToDeleteIds = [];

        for (int idToDelete in List.from(_imageIdsToDelete)) {
          if (idToDelete > 0) {
            try {
              bool success = await LocationController.removeLocationImage(
                  locationId: widget.locationId, imageId: idToDelete);
              if (success) {
                successfullyDeletedIds.add(idToDelete);
              } else {
                failedToDeleteIds.add(idToDelete);
                imageDeletionFailed = true;
              }
            } catch (e) {
              failedToDeleteIds.add(idToDelete);
              imageDeletionFailed = true;
            }
          } else {
            successfullyDeletedIds.add(idToDelete);
          }
        }

        setStateIfMounted(() {
          _imageIdsToDelete
              .removeWhere((id) => successfullyDeletedIds.contains(id));
          if (successfullyDeletedIds.isNotEmpty) {
            changesSuccessfullySaved = true;
          }
        });

        if (imageDeletionFailed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "Could not delete images: ${failedToDeleteIds.join(', ')}")));
        }
      }

      // --- Upload new images ---
      bool imageUploadFailed = false;
      if (newImages.isNotEmpty) {
        List<File> successfullyUploaded = [];
        for (File imageToAdd in List.from(newImages)) {
          try {
            Uint8List imageBytes = await imageToAdd.readAsBytes();
            bool addSuccess = await LocationController.addLocationImage(
                locationId: widget.locationId, imageBytes: imageBytes);
            if (addSuccess) {
              successfullyUploaded.add(imageToAdd);
            } else {
              imageUploadFailed = true;
            }
          } catch (e) {
            imageUploadFailed = true;
          }
        }
        setStateIfMounted(() {
          newImages.removeWhere((file) => successfullyUploaded.contains(file));
          if (successfullyUploaded.isNotEmpty) {
            changesSuccessfullySaved = true;
          }
        });
        if (imageUploadFailed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Failed to upload one or more images.")));
        }
      }

      // --- Update Location Details ---
      final name = _nameController.text.trim();
      if (name.isEmpty) throw Exception("Location name required");

      int capacity;
      try {
        capacity = int.parse(_capacityController.text.trim());
        if (capacity < 0) capacity = 0;
      } catch (e) {
        throw Exception("Valid capacity (>= 0) required");
      }

      final description = _descriptionController.text.trim();
      int? parentLocationId = (selectedParentLocation != "None")
          ? locationNameToId[selectedParentLocation]
          : null;

      final int ownerId = location!.ownerId;

      String? firstImageValue;
      final List<LocationImage> visibleExistingImages = existingImages
          .where((img) => !_imageIdsToDelete.contains(img.imageId))
          .toList();
      if (visibleExistingImages.isNotEmpty &&
          visibleExistingImages.first.imageBin != null) {
        firstImageValue = visibleExistingImages.first.imageBin;
      }

      bool detailsOrParentChanged = location!.name != name ||
          location!.capacity != capacity ||
          (location!.description ?? '') != description ||
          location!.parentLocationId != parentLocationId;

      if (detailsOrParentChanged) {
        detailsUpdateAttempted = true;

        final updatedLocationData = await LocationController.updateLocation(
          locationId: widget.locationId,
          name: name,
          capacity: capacity,
          ownerId: ownerId,
          description: description.isEmpty ? null : description,
          parentLocationId: parentLocationId,
          firstImage: firstImageValue,
        );

        if (updatedLocationData != null) {
          setStateIfMounted(() {
            location = updatedLocationData;
          });
          changesSuccessfullySaved = true;
        } else {
          await loadLocationData();
          changesSuccessfullySaved = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Details saved (check logs for details).")));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("No changes detected in location details or parent.")),
          );
        }
      }

      if (changesSuccessfullySaved) {
        // Reloads data after successful changes to ensure UI reflects updates and switches back to view mode
        await loadLocationData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location updated successfully")),
          );
          widget.onSave();
        }
      } else {
        if (imageChanges && !detailsUpdateAttempted) {
          await loadLocationData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Image changes saved")),
            );
            widget.onSave();
          }
        } else if (!imageChanges && !detailsUpdateAttempted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No changes detected")),
            );
            widget.onCancel();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating location: $e")),
        );
      }
    } finally {
      setStateIfMounted(() {
        isLoading = false;
      });
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Builds the image display section for the edit page
  Widget buildEditableLocationImages() {
    List<Widget> imageWidgets = [];

    for (var image in existingImages) {
      // Only displays images not marked for deletion
      if (!_imageIdsToDelete.contains(image.imageId)) {
        try {
          final String imageBinString = image.imageBin ?? '';
          if (imageBinString.isEmpty) throw Exception("Empty image data ID ${image.imageId}");
          Uint8List imageBytes = base64Decode(imageBinString);

          imageWidgets.add(Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.memory(imageBytes,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image,
                              color: Colors.red))),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: () => deleteExistingImage(image.imageId),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.redAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ));
        } catch (e) {
          imageWidgets.add(Padding(
              padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
              child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.red))));
        }
      }
    }

    // Adds Newly Selected Images (with remove button)
    for (var imageFile in newImages) {
      imageWidgets.add(Padding(
        padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.file(
                imageFile,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[200],
                    child:
                        const Icon(Icons.error_outline, color: Colors.orange)),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: InkWell(
                onTap: () => removeNewImage(imageFile),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle),
                  child: const Icon(Icons.remove_circle_outline,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ));
    }

    // Adds the "Add Image" Button
    imageWidgets.add(Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: 100,
        height: 100,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[200],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              padding: EdgeInsets.zero),
          onPressed: showImageSourceDialog,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined,
                  color: Colors.grey[600], size: 30),
              const SizedBox(height: 4),
              Text("Add Image",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ),
    ));
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: imageWidgets,
    );
  }
  // ==========================================================================

  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (isLoading && location == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (location == null) {
      return const Center(child: Text("Failed to load location data."));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.symmetric(vertical: 10.0)),

              // --- Images Section ---
              const Text("Illustrations",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 4.0)),
              buildEditableLocationImages(),
              const Padding(padding: EdgeInsets.symmetric(vertical: 6.0)),

              // --- Details Section ---
              const Text("Details",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 4.0)),
              TextBox(
                key: _nameKey,
                backText: 'Name',
                featureButton: _nameClearButton,
                boxC: _nameController,
                boxWidth: double.infinity,
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 4.0)),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                      color: const Color.fromARGB(255, 87, 143, 134),
                      width: 1.5),
                ),
                child: TextField(
                  key: _capacityKey,
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Capacity',
                    labelStyle: TextStyle(
                        color: const Color(0xFF4F8079).withAlpha(179)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 10.0),
                    suffixIcon: _capacityClearButton,
                  ),
                ),
              ),

              const Padding(padding: EdgeInsets.symmetric(vertical: 4.0)),
              Container(
                width: double.infinity,
                constraints:
                    const BoxConstraints(minHeight: 50, maxHeight: 100),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                      color: const Color.fromARGB(255, 87, 143, 134),
                      width: 1.5),
                ),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(
                        color: const Color(0xFF4F8079).withAlpha(179)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 10.0),
                    suffixIcon: _descriptionClearButton,
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 4.0)),

              MultipleChoiceButton(
                backText: 'Parent Location',
                boxWidth: double.infinity,
                returnType: _handleParentLocationChange,
                identifier: 0,
                fields: availableLocations,
                prefillType: selectedParentLocation,
              ),

              const Padding(padding: EdgeInsets.symmetric(vertical: 20.0)),
              if (isLoading && location != null)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
  // ==========================================================================
}
