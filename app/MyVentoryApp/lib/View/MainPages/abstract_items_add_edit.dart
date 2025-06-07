import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';
import 'package:my_ventory_mobile/Controller/item_controller.dart';
import 'package:my_ventory_mobile/Controller/location_controller.dart';
import 'package:my_ventory_mobile/Controller/user_controller.dart';
import 'package:my_ventory_mobile/Model/clear_text_button.dart';
import 'package:my_ventory_mobile/Model/context_buttons.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/Model/location.dart';
import 'package:my_ventory_mobile/Model/multiple_choice_button.dart';
import 'package:my_ventory_mobile/Model/overlay_feature.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';
import 'package:my_ventory_mobile/View/MainPages/inventory_page.dart';
import 'package:my_ventory_mobile/View/custom_location_selector.dart';
import 'package:my_ventory_mobile/View/item_view_page.dart';
import 'package:my_ventory_mobile/View/picture_page.dart';
import 'package:my_ventory_mobile/View/quantity_spinner.dart';

class AbstractItemsAddEdit extends StatefulWidget {
  final int? itemId;
  final InventoryItem? externalItem;
  final List<ItemAttribute>? externalAttr;
  final bool isAdd;

  const AbstractItemsAddEdit({
    super.key,
    this.itemId,
    this.externalItem,
    this.externalAttr,
  }) : isAdd = itemId == null;

  @override
  State<AbstractItemsAddEdit> createState() => AbstractItemsAddEditState();
}

class AbstractItemsAddEditState extends State<AbstractItemsAddEdit> {
  // ==========================================================================
  // Variables
  InventoryItem? item;

  List<ItemImage> images = [];
  bool isLoading = true;
  int? selectedLocationId;

  int textFields = 3;
  int id = 1;

  List<TextEditingController> tc = [];
  List<GlobalKey<TextBoxState>> keys = [];
  List<ClearTextButton> ctbs = [];

  List<String> dataFromType = [];
  List<String> sendAttrData = [];

  List<List<Widget>> attributeWaves = [];
  OverlayEntry? oE;

  List<ItemAttribute> attributes = [];
  List<ItemAttribute> usrAttributes = [];
  Map<String, String> usrAttributesNamesTypes = {};

  late List<Location> locs;
  List<String> locationsNames = [];
  Map<String, int> locationIdMap = {};

  List<String> newImagesPaths = [];
  List<ItemImage> existingImages = [];
  bool imageChanges = false;
  final List<int> imageIdsToDelete = [];

  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _webImageBytes = [];
  final List<XFile> _selectedWebImages = [];

  late int? currentUserId;

  @override
  void initState() {
    super.initState();

    setState(() {
      isLoading = true;
    });

    for (var i = 0; i < textFields; i++) {
      TextEditingController tec = TextEditingController();
      GlobalKey<TextBoxState> key = GlobalKey<TextBoxState>();
      ClearTextButton ctb = ClearTextButton(textBoxKey: key, boxC: tec);
      tc.add(tec);
      keys.add(key);
      ctbs.add(ctb);
    }

    dataFromType.add("");
  }

  bool firstBuild = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (firstBuild) {
      firstBuild = false;
      callElements();
    }
  }

  // ==========================================================================
  // Instantiate every informations needed (item, attributes, location, ...)
  // ==========================================================================
  void callElements() {
    generateElements();
  }

  Future<void> generateElements() async {
    if (widget.itemId != null) {
      item = await ItemController.getItemById(widget.itemId!);
      List<ItemAttribute> attributesData = [];
      try {
        attributesData =
            await ItemController.getAttributesForItem(item!.itemId);
      } catch (e) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to load item attributes : $e")),
            );
          }
        });
      }
      attributes = attributesData;
      try {
        existingImages = await ItemController.getItemImages(item!.itemId) ?? [];
      } catch (e) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to load item pictures : $e")),
            );
          }
        });
      }
    }

    await fetchUserAndLocation();

    if (widget.externalItem != null) {
      item = widget.externalItem;
      if (item!.images?.isNotEmpty ?? false) {
        newImagesPaths.addAll(item!.images!.map((image) => image.imageBin));
      }
    }
    if (widget.externalAttr != null) {
      attributes = widget.externalAttr!;
    }

    if (attributes.isNotEmpty) {
      for (var attr in attributes) {
        addAttribute(attr);
      }
    }

    if (item != null) {
      loadItemData(item);
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchUserAndLocation() async {
    currentUserId = await AuthService.getUserId();
    usrAttributes =
        await UserController.getAttributesOfUser(currentUserId!) ?? [];
    locs = await getLocations();
    if (!mounted) return;
    setState(() {
      locationsNames = ["Choose a Location"];
      locationIdMap = {"Choose a Location": -1};

      for (var loc in locs) {
        locationsNames.add(loc.name);
        locationIdMap[loc.name] = loc.locationId;
      }

      for (var attr in usrAttributes) {
        usrAttributesNamesTypes[attr.name] = attr.type;
      }
    });
  }

  Future<List<Location>> getLocations() async {
    return await UserController.getLocationsOfUser(currentUserId!) ?? [];
  }

  // ==========================================================================
  // Pre-fill the text boxes based out of the item data
  // ==========================================================================
  Future<void> loadItemData(InventoryItem? item) async {
    try {
      if (item != null) {
        tc[0].text = item.name;
        tc[1].text = item.quantity.toString();
        tc[2].text = item.description;

        String locationName = "";
        if (item.location != null) {
          locationName = item.location!;
        } else {
          locationName = locationsNames[0];
        }

        setState(() {
          dataFromType[0] = locationName;
          if (locationName.isNotEmpty &&
              locationIdMap.containsKey(locationName)) {
            selectedLocationId = locationIdMap[locationName];
          }
        });
      } else {
        if (mounted) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Item not found")),
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to load item: $e")),
            );
          }
        });
      }
    }
  }

  // ==========================================================================
  // Method to get data from the different type buttons inputs
  void getDataFromMultipleChoice(String type, int identifier) {
    setState(() {
      if (identifier >= 0) {
        while (identifier >= dataFromType.length) {
          dataFromType.add("");
        }
        
        String previousType = dataFromType[identifier];
        
        dataFromType[identifier] = type;
        
        if (identifier != 0) {
          int valueIndex = 3 + ((identifier - 1) * 2) + 1;
          
          if (valueIndex < tc.length) {
            String currentValue = tc[valueIndex].text;
            
            if (previousType != type) {
              if (type == "Category") {
                tc[valueIndex].text = "N/A";
              } else if (type == "Date") {
                final now = DateTime.now();
                tc[valueIndex].text = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
              } else if (type == "Number") {
                tc[valueIndex].text = "0.00";
              } else if (type == "Currency") {
                tc[valueIndex].text = "€0.00";
              } else if (type == "Link") {
                if (currentValue.isEmpty ||
                    !(currentValue.startsWith("http://") ||
                        currentValue.startsWith("https://"))) {
                  tc[valueIndex].text = "https://";
                }
              } else {
                tc[valueIndex].text = "";
              }
            }
          }
        }
      }
    });
  }
  // ==========================================================================

  // ==========================================================================
  // Method to add a new attribute selection to the user when the + button in the bottom is pushed.
  void addAttribute(ItemAttribute? attr) {
    setState(() {
      List<Widget> currentWave = [];
      String initialType = attr?.type ?? "Text";
      ValueNotifier<String> valueTypeNotifier = ValueNotifier<String>(initialType);
      
      // Calculates new identifier for this attribute
      // This ensures we're using a unique identifier that matches dataFromType's index
      int identifier = dataFromType.length;
      dataFromType.add(initialType);

      for (var i = textFields; i < textFields + 2; i++) {
        TextEditingController tec = TextEditingController();
        GlobalKey<TextBoxState> key = GlobalKey<TextBoxState>();
        ClearTextButton ctb = ClearTextButton(textBoxKey: key, boxC: tec);
        tc.add(tec);
        keys.add(key);
        ctbs.add(ctb);
      }
      
      GlobalKey<MultipleChoiceButtonState> mcKey = GlobalKey<MultipleChoiceButtonState>();

      // Fills textfields if attributes exists otherwise give basic values based on type
      if (attr != null) {
        tc[textFields].text = attr.name;
        tc[textFields + 1].text = attr.value;
      } else {
        if (initialType == "Category") {
          tc[textFields + 1].text = "";
        } else if (initialType == "Date") {
          final now = DateTime.now();
          tc[textFields + 1].text = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
        } else if (initialType == "Number") {
          tc[textFields + 1].text = "0.00";
        } else if (initialType == "Currency") {
          tc[textFields + 1].text = "€0.00";
        } else if (initialType == "Link") {
          tc[textFields + 1].text = "https://";
        } else {
          tc[textFields + 1].text = "";
        }
      }
      
      currentWave.add(const Padding(padding: EdgeInsets.symmetric(vertical: 2.0)));
      currentWave.add(
        Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            setState(() {
              int indexToRemove = attributeWaves.indexOf(currentWave);
              
              // Removes from dataFromType (but only if in range)
              if (indexToRemove + 1 < dataFromType.length) {
                dataFromType.removeAt(indexToRemove + 1);
              }
              
              // Calculates starting index for removing controllers, keys, and buttons
              if (3 + indexToRemove * 2 < tc.length) {
                for (var i = 0; i < 2; i++) {
                  tc.removeAt(3 + indexToRemove * 2);
                  keys.removeAt(3 + indexToRemove * 2);
                  ctbs.removeAt(3 + indexToRemove * 2);
                }
              }
              
              textFields -= 2;
              attributeWaves.remove(currentWave);

              id = dataFromType.length;
            });
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Column(
            children: [
              TextBox(
                key: keys[textFields],
                backText: 'Name',
                featureButton: ctbs[textFields],
                boxC: tc[textFields],
                boxWidth: (MediaQuery.of(context).size.width - 40),
                suggestions: usrAttributesNamesTypes,
                onSuggestionSelected: (String selection) {
                  mcKey.currentState?.updateSelectedType(selection);
                },
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 2.0)),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: MultipleChoiceButton(
                      key: mcKey,
                      backText: 'Type',
                      boxWidth: double.infinity,
                      returnType: getDataFromMultipleChoice,
                      identifier: identifier,
                      fields: [
                        "Text",
                        "Number",
                        "Currency",
                        "Date",
                        "Link",
                        "Category"
                      ],
                      prefillType: initialType,
                      typeNotifier: valueTypeNotifier,
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 3.0)),
                  Expanded(
                    flex: 1,
                    child: ValuesTextBox(
                      typeNotifier: valueTypeNotifier,
                      tc: tc[textFields + 1],
                      textboxkey: keys[textFields + 1],
                      ctb: ctbs[textFields + 1],
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      );
      
      currentWave.add(const Padding(padding: EdgeInsets.symmetric(vertical: 8.0)));
      // Add to waves collection
      attributeWaves.add(currentWave);
      textFields = textFields + 2;
      id = dataFromType.length;
    });
  }
  // ==========================================================================

  // ==========================================================================
  // Method to recover, prepare and send data trought the API
  Future<void> addItem() async {
    if (int.tryParse(tc[1].text) == null) {
      OverlayFeature.displayMessageOverlay(
          context, false, "The quantity must be a number");
      return;
    }

    // Create the item first
    InventoryItem? addedItem;
    try {
      addedItem = await ItemController.createItem(
        name: tc[0].text,
        quantity: int.tryParse(tc[1].text) ?? 0,
        description: tc[2].text,
        ownerId: currentUserId!,
      );

      if (addedItem == null) {
        if (!mounted) return;
        OverlayFeature.displayMessageOverlay(
            context, false, "We couldn't add you item to your inventory");
        return;
      }
    } catch (e) {
      if (!mounted) return;
      OverlayFeature.displayMessageOverlay(
          context, false, "We couldn't add you item to your inventory");
      return;
    }

    final selectedLocationName = dataFromType[0];
    if (selectedLocationName.isNotEmpty &&
        selectedLocationName != "Choose a Location") {
      final selectedLocation = locs.firstWhere(
        (loc) => loc.name == selectedLocationName,
      );

      try {
        bool success = await LocationController.moveItemToLocation(
          locationId: selectedLocation.locationId,
          itemId: addedItem.itemId,
        );
        if (!success) {
          if (!mounted) return;
          OverlayFeature.displayMessageOverlay(
              context, false, "The item couldn't be added to this location");
          return;
        }
      } catch (e) {
        if (!mounted) return;
        OverlayFeature.displayMessageOverlay(
            context, false, "The item couldn't be added to this location");
        return;
      }
    }

    // Upload mobile file images
    for (String imageToAddPath in newImagesPaths) {
      Uint8List imageBytes;

      if (imageToAddPath.startsWith("http://") ||
          imageToAddPath.startsWith("https://")) {
        final response = await http.get(Uri.parse(imageToAddPath));
        if (response.statusCode != 200) {
          throw Exception("Failed to download image");
        }
        imageBytes = response.bodyBytes;
      } else {
        imageBytes = await File(imageToAddPath).readAsBytes();
      }

      try {
        bool addImageSuccess = await ItemController.addItemImage(
            itemId: addedItem.itemId,
            imageBytes: imageBytes,
            filename: imageToAddPath);

        if (!addImageSuccess) {
          if (!mounted) return;
          OverlayFeature.displayMessageOverlay(
              context, false, "The images couldn't be added to your item");
          return;
        }
      } catch (e) {
        if (!mounted) return;
        OverlayFeature.displayMessageOverlay(
            context, false, "The images couldn't be added to your item");
        return;
      }
    }

    // Upload web platform images
    for (int i = 0; i < _webImageBytes.length; i++) {
      try {
        String filename = _selectedWebImages[i].name;
        bool addImageSuccess = await ItemController.addItemImage(
            itemId: addedItem.itemId,
            imageBytes: _webImageBytes[i],
            filename: filename);

        if (!addImageSuccess) {
          if (!mounted) return;
          OverlayFeature.displayMessageOverlay(
              context, false, "The images couldn't be added to your item");
          return;
        }
      } catch (e) {
        if (!mounted) return;
        OverlayFeature.displayMessageOverlay(
            context, false, "The images couldn't be added to your item");
        return;
      }
    }

    List<Map<String, String>> attr = [];
    int i = 3;
    while (i < tc.length - 1) {
      attr.add({
        'itemId': addedItem.itemId.toString(),
        'name': tc[i].text,
        'type': dataFromType[((i - 1) / 2).toInt()],
        'value': tc[i + 1].text
      });
      i += 2;
    }

    if (attr.isNotEmpty) {
      try {
        await ItemController.addItemAttributes(
            itemId: addedItem.itemId, attributes: attr);
      } catch (e) {
        if (!mounted) return;
        OverlayFeature.displayMessageOverlay(
            context, false, "The attributes couldn't be added to your item");
        return;
      }
    }

    if (!mounted) return;
    OverlayFeature.displayMessageOverlay(
        context, true, "Your item has been successfully added !");
  }
  // ==========================================================================

  // ==========================================================================
  // Method to update the item
  Future<void> updateItem(int itemId) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    bool changesMade = false;

    try {
      // Remove image if some has been deleted
      if (imageIdsToDelete.isNotEmpty) {
        try {
          bool deleteSuccess = await ItemController.removeItemImage(
            itemId: itemId,
            imageIds: List.from(imageIdsToDelete),
          );
          if (deleteSuccess) {
            changesMade = true;
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Unable to delete marked images")),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Unable to reach API")),
            );
          }
          throw Exception("Unable to reach the API");
        }
      }

      // Upload mobile file system images
      List<File> successfullyUploaded = [];
      if (newImagesPaths.isNotEmpty) {
        for (String imageToAddPath in newImagesPaths) {
          try {
            Uint8List imageBytes = await File(imageToAddPath).readAsBytes();
            String filename = imageToAddPath.split('/').last;
            bool addImageSuccess = await ItemController.addItemImage(
                itemId: itemId, imageBytes: imageBytes, filename: filename);
            if (addImageSuccess) {
              changesMade = true;
              successfullyUploaded.add(File(imageToAddPath));
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to add an image")),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Unable to reach API")),
              );
            }
          }
        }
        setState(() {
          newImagesPaths
              .removeWhere((path) => successfullyUploaded.contains(File(path)));
        });
      }

      // Upload web platform images
      List<int> successfullyUploadedWebImages = [];
      for (int i = 0; i < _webImageBytes.length; i++) {
        try {
          String filename = _selectedWebImages[i].name;
          bool addImageSuccess = await ItemController.addItemImage(
              itemId: itemId, imageBytes: _webImageBytes[i], filename: filename);
          if (addImageSuccess) {
            changesMade = true;
            successfullyUploadedWebImages.add(i);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Failed to add a web image")),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Unable to reach API")),
            );
          }
        }
      }
      
      // Remove successfully uploaded web images from state
      if (successfullyUploadedWebImages.isNotEmpty) {
        setState(() {
          // Remove from highest index to lowest to avoid index shifting issues
          successfullyUploadedWebImages.sort((a, b) => b.compareTo(a));
          for (int index in successfullyUploadedWebImages) {
            _webImageBytes.removeAt(index);
            _selectedWebImages.removeAt(index);
          }
        });
      }

      // Update name/qtity/decription of item
      int quantity = int.tryParse(tc[1].text) ?? item?.quantity ?? 0;
      if (quantity < 1) quantity = 1;

      bool needsItemUpdate = item!.name != tc[0].text ||
          item!.quantity != quantity ||
          item!.description != tc[2].text;

      if (needsItemUpdate) {
        bool itemUpdateResult = await ItemController.updateItem(
          itemId: itemId,
          newName: tc[0].text,
          newDescription: tc[2].text,
          newQuantity: quantity,
          ownerId: item?.ownerId ?? 1,
        );
        if (itemUpdateResult) {
          changesMade = true;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to update item details")),
            );
          }
        }
      }

      // Update attributes of items
      Map<String, ItemAttribute> existingAttributesByName = {
        for (var attr in attributes) attr.name.toLowerCase(): attr
      };
      List<ItemAttribute> attributesToRemove = [];
      List<Map<String, String>> attributesToAddOrUpdate = [];
      Set<String> currentAttributeNames = {};

      for (int i = 0; i < attributeWaves.length; i++) {
        int nameIdx = 3 + (i * 2);
        int valueIdx = nameIdx + 1;
        int attrTypeIdx = i + 1;

        if (nameIdx < tc.length && tc[nameIdx].text.isNotEmpty) {
          String attrName = tc[nameIdx].text;
          String attrNameLower = attrName.toLowerCase();
          currentAttributeNames.add(attrNameLower);
          String attrType = dataFromType[attrTypeIdx];
          String attrValue = (valueIdx < tc.length) ? tc[valueIdx].text : '';

          if (existingAttributesByName.containsKey(attrNameLower)) {
            var existingAttr = existingAttributesByName[attrNameLower]!;
            bool attributeChanged = existingAttr.value != attrValue ||
                existingAttr.type != attrType;

            if (attributeChanged) {
              // If attribute exists but changed, mark old one for removal and add new one
              attributesToRemove.add(existingAttr);
              attributesToAddOrUpdate.add(
                  {"type": attrType, "name": attrName, "value": attrValue});
            }
          } else {
            attributesToAddOrUpdate
                .add({"type": attrType, "name": attrName, "value": attrValue});
          }
        }
      }

      for (var attr in attributes) {
        if (!currentAttributeNames.contains(attr.name.toLowerCase())) {
          attributesToRemove.add(attr);
        }
      }

      if (attributesToRemove.isNotEmpty) {
        List<int> idsToRemove = attributesToRemove
            .map((attr) => attr.attributeId)
            .where((id) => id > 0)
            .toList(); // Ensure valid IDs
        if (idsToRemove.isNotEmpty) {
          for (var attr in attributesToRemove) {
            if (attr.attributeId > 0) {
              await ItemController.removeItemAttribute(
                  itemId: itemId, attributeId: attr.attributeId);
            }
          }
          changesMade = true;
        }
      }

      if (attributesToAddOrUpdate.isNotEmpty) {
        await ItemController.addItemAttributes(
            itemId: itemId, attributes: attributesToAddOrUpdate);
        changesMade = true;
      }

      // Update location where the item is stored
      String selectedLocationName = dataFromType[0];
      int? newLocationId;
      if (selectedLocationName.isNotEmpty &&
          selectedLocationName != "Choose a Location") {
        newLocationId = locationIdMap[selectedLocationName];
      }

      bool locationChanged = selectedLocationId != newLocationId;
      if (locationChanged) {
        try {
          if (newLocationId != null && newLocationId > 0) {
            bool moveSuccess = await LocationController.moveItemToLocation(
              locationId: newLocationId,
              itemId: itemId,
            );
            if (moveSuccess) changesMade = true;
          } else if (selectedLocationId != null && selectedLocationId! > 0) {
            // Remove from current location if 'None' or 'Choose' was selected
            bool removeSuccess =
                await LocationController.removeItemFromLocation(
              locationId: selectedLocationId!,
              itemId: itemId,
            );
            if (removeSuccess) changesMade = true;
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Unable to reach API")),
            );
          }
        }
      }

      if (changesMade) {
        if (imageIdsToDelete.isNotEmpty) {
          // Assuming deletion succeeded if no exception was thrown earlier
          imageIdsToDelete.clear();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Item updated successfully")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No changes detected")),
          );
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating item: $e")),
        );
      }
    }
  }

  Future<void> deleteItem() async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Delete Item"),
          content: const Text("Are you sure you want to delete this item?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                setState(() {
                  isLoading = true;
                });

                try {
                  final success = await ItemController.deleteItem(item!.itemId);
                  if (success && mounted) {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (BuildContext context) => InventoryPage(),
                      ),
                    );
                  } else {
                    if (mounted) {
                      setState(() {
                        isLoading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Failed to delete item")),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      isLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e")),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void deleteImage(int imageId) {
    if (!imageIdsToDelete.contains(imageId)) {
      setState(() {
        imageIdsToDelete.add(imageId);
        imageChanges = true;
      });
    }
  }

  Widget displayImages(bool imageFromNet, String imagePath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: imageFromNet
          ? Image.network(
              imagePath,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.red));
              },
            )
          : Image.file(
              File(imagePath),
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.red));
              },
            ),
    );
  }

  Widget buildItemImages() {
    List<Widget> imageWidgets = [];
    
    // Existing images from the database
    for (var image in existingImages) {
      if (!imageIdsToDelete.contains(image.imageId)) {
        try {
          imageWidgets.add(Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.memory(
                    base64Decode(image.imageBin),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.red,
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: () => deleteImage(image.imageId),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
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
              padding: const EdgeInsets.only(right: 8.0),
              child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.red))));
        }
      }
    }

    // New images added during the current session (from mobile file system)
    for (var imagePath in newImagesPaths) {
      bool imageFromNet =
          imagePath.startsWith("http://") || imagePath.startsWith("https://");
      imageWidgets.add(Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            displayImages(imageFromNet, imagePath),
            Positioned(
              top: 2,
              right: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    newImagesPaths.remove(imagePath);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove_circle_outline,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ));
    }

    // Web platform images (using bytes)
    for (int i = 0; i < _webImageBytes.length; i++) {
      imageWidgets.add(Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.memory(
                _webImageBytes[i],
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.red,
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _webImageBytes.removeAt(i);
                    _selectedWebImages.removeAt(i);
                    imageChanges = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove_circle_outline,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ));
    }

    // Add button for adding new images
    // Different implementation based on platform
    imageWidgets.add(Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
        width: 100,
        height: 100,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          onPressed: () async {
            if (kIsWeb) {
              // Web platform - use image picker directly
              await _pickWebImage();
            } else {
              // Mobile platform - use existing dialog
              List<String> pickedPaths =
                  await PicturePage.showImageSourceDialog(context);
              setState(() {
                for (String path in pickedPaths) {
                  newImagesPaths.add(path);
                }
                imageChanges = true;
              });
            }
          },
          child: Icon(Icons.add_a_photo_outlined,
              color: Colors.grey[600], size: 30),
        ),
      ),
    ));

    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        children: imageWidgets,
      ),
    );
  }

  Future<void> _pickWebImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedWebImages.add(pickedFile);
          _webImageBytes.add(bytes);
          imageChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking image: $e")),
        );
      }
    }
  }

  Widget addButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 0, 150, 136),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(
              vertical: 20.0, horizontal: 20.0),
        ),
        label: const Text(
          "Add to my inventory",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        icon: const Icon(Icons.check, color: Colors.white),
        onPressed: () async {
          await addItem();
          if (!mounted) return;
          Navigator.of(context).popAndPushNamed('/add');
        },
      ),
    );
  }

  Widget editButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 0, 150, 136),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            ),
            label: const Text(
              "Update item",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            icon: const Icon(Icons.update, color: Colors.white),
            onPressed: () async {
              await updateItem(item!.itemId);
              if (!mounted) return;
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (BuildContext context) => ItemViewPage(
                    itemId: widget.itemId!,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withAlpha(204),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            ),
            label: const Text(
              "Delete item",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              await deleteItem();
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ==========================================================================
              // Upper part buttons to let the user add/edit or delete depending on the page he stands
              // ==========================================================================
              Padding(padding: EdgeInsets.symmetric(vertical: 20.0)),
              if (!widget.isAdd)
                Align(
                  alignment: Alignment(-1, 0),
                  child: GoBackButton(
                    pushedWidget: ItemViewPage(itemId: widget.itemId!),
                  ),
                ),
              widget.isAdd ? addButton() : editButton(),
              const Padding(padding: EdgeInsets.symmetric(vertical: 6.0)),
              const Align(
                alignment: Alignment(-1, 0),
                child: Text(
                  "Illustrations",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
              buildItemImages(),
              const Padding(padding: EdgeInsets.symmetric(vertical: 6.0)),
              const Align(
                alignment: Alignment(-1, 0),
                child: Text(
                  "Details",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 2.0)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tc[0],
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 10.0),
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 2.0)),
              TextField(
                controller: tc[2],
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 10.0),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 2.0)),
              CustomLocationSelector(
                currentLocation: dataFromType[0],
                locations: locationsNames
                    .where((loc) => loc != "Choose a Location")
                    .toList(),
                onLocationSelected: (selectedLocation) {
                  getDataFromMultipleChoice(selectedLocation, 0);
                },
                width: (MediaQuery.of(context).size.width - 40),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 5.0)),
              const Align(
                alignment: Alignment(-1, 0),
                child: Text(
                  "Quantity",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
              QuantitySpinner(
                controller: tc[1],
                width: (MediaQuery.of(context).size.width - 40) * (2 / 5) - 3,
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      "More Info",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(width: 8),
                    Tooltip(
                      message: "Slide left to delete the info",
                      child: Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: attributeWaves.expand((wave) => wave).toList(),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 15.0)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(60, 60),
                  backgroundColor: const Color.fromARGB(255, 0, 150, 136),
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 16.0),
                ),
                onPressed: () => addAttribute(null),
                icon: const Icon(Icons.add, size: 24, color: Colors.white),
                label: const Text(
                  "Add Info",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 20.0)),
            ],
          ),
        ),
      ),
    );
  }
}
