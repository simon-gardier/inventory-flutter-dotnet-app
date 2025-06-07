import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Controller/item_controller.dart';
import 'package:my_ventory_mobile/Model/context_buttons.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/Model/page_template.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';
import 'package:my_ventory_mobile/View/MainPages/inventory_page.dart';
import 'package:my_ventory_mobile/View/item_edit_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:my_ventory_mobile/View/in_app_web_view.dart';

// ==========================================================================
// StatefulWidget displaying detailed view of an inventory item
// ==========================================================================
class ItemViewPage extends PageTemplate {
  final int itemId;

  const ItemViewPage({
    super.key,
    required this.itemId,
  });

  @override
  PageTemplateState<ItemViewPage> createState() => ItemViewPageState();
}

class ItemViewPageState extends PageTemplateState<ItemViewPage> {
  // ==========================================================================
  // Variables
  InventoryItem? item;
  List<ItemAttribute> attributes = [];
  List<ItemImage> images = [];
  bool isLoading = true;
  bool isBorrowedItem = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController parentItemController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadItemData();
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    descriptionController.dispose();
    parentItemController.dispose();
    locationController.dispose();
    super.dispose();
  }
  // ==========================================================================

  // ==========================================================================
  // Loads item data from cache or network
  // ==========================================================================
  Future<void> loadItemData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      await loadData();
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load item: $e")),
        );
      }
    }
  }

  // ==========================================================================
  // Helper method to load data from network and update cache
  // ==========================================================================
  Future<void> loadData() async {
    if (!mounted) return;

    try {
      // First check if this is a cached borrowed item
      if (ItemController.isBorrowedItemCached(widget.itemId)) {
        // We have a cached borrowed item, use it directly
        final cachedItem = ItemController.getCachedBorrowedItem(widget.itemId);
        if (cachedItem != null) {
          setState(() {
            item = cachedItem;
            isBorrowedItem = true;

            // Set the text controllers
            nameController.text = cachedItem.name;
            quantityController.text = cachedItem.quantity.toString();
            descriptionController.text = cachedItem.description;

            // Use images from the borrowed item if available
            if (cachedItem.images != null && cachedItem.images!.isNotEmpty) {
              images = cachedItem.images!;
            }

            // Use attributes from the borrowed item if available
            if (cachedItem.attributes != null &&
                cachedItem.attributes!.isNotEmpty) {
              attributes = cachedItem.attributes!;
            }

            isLoading = false;
          });
          return;
        }
      }

      // If not a cached borrowed item, try to get it from the API
      final itemData = await ItemController.getItemById(widget.itemId);
      if (itemData == null || !mounted) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Check if this is a borrowed item
      isBorrowedItem =
          itemData.borrowedFrom != null && itemData.borrowedFrom!.isNotEmpty;

      nameController.text = itemData.name;
      quantityController.text = itemData.quantity.toString();
      descriptionController.text = itemData.description;
      // If the item has a location, store it in the locationController
      if (itemData.location != null && itemData.location!.isNotEmpty) {
        locationController.text = itemData.location!;
      }

      setState(() {
        item = itemData;

        // Use images from the item if available
        if (itemData.images != null && itemData.images!.isNotEmpty) {
          images = itemData.images!;
        }

        // Use attributes from the item if available
        if (itemData.attributes != null && itemData.attributes!.isNotEmpty) {
          attributes = itemData.attributes!;
        }

        isLoading = false;
      });

      // If we don't have images or attributes already, try to load them
      if (images.isEmpty) {
        await loadImages();
      }

      if (attributes.isEmpty) {
        await loadAttributes();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ==========================================================================
  // Loads item attributes
  // ==========================================================================
  Future<void> loadAttributes() async {
    try {
      // Skip loading attributes if we already have them from a borrowed item
      if (isBorrowedItem &&
          item?.attributes != null &&
          item!.attributes!.isNotEmpty) {
        return;
      }

      List<ItemAttribute> attributesData =
          await ItemController.getAttributesForItem(widget.itemId);
      if (mounted) {
        setState(() {
          attributes = attributesData;
        });
      }
    } catch (e) {
      // no need to handle catch
    }
  }

  // ==========================================================================
  // Loads item images
  // ==========================================================================
  Future<void> loadImages() async {
    try {
      // Skip loading images if we already have them from a borrowed item
      if (isBorrowedItem && item?.images != null && item!.images!.isNotEmpty) {
        return;
      }

      List<ItemImage> imagesData =
          await ItemController.getItemImages(widget.itemId) ?? [];
      if (mounted) {
        setState(() {
          images = imagesData;
        });
      }
    } catch (e) {
      // Silently handle error - the user will simply see "No images available"
    }
  }

  // ==========================================================================
  // Builds the location field widget showing item's location
  // ==========================================================================
  Widget buildLocationField() {
    Widget locationText = item?.location != null && item!.location!.isNotEmpty
        ? Text(
            item!.location!,
            style: const TextStyle(fontSize: 16),
          )
        : const Text(
            "No Location",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black38,
              fontStyle: FontStyle.italic,
            ),
          );

    return StaticTextBox(
      label: "Location",
      width: MediaQuery.of(context).size.width - 40,
      childText: locationText,
    );
  }

  // ==========================================================================
  // Builds borrowing info section for borrowed items
  // ==========================================================================
  Widget buildBorrowingInfo() {
    if (!isBorrowedItem ||
        item == null ||
        item!.borrowedFrom == null ||
        item!.dueDate == null) {
      return SizedBox.shrink();
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    final String formattedDueDate = dateFormat.format(item!.dueDate!);
    final bool isOverdue = item!.dueDate!.isBefore(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
        Container(
          width: 300,
          height: 2,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.rectangle),
        ),
        const SizedBox(height: 15),
        const Text(
          "Borrowing Information",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Color.fromRGBO(255, 255, 255, 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color.fromARGB(255, 87, 143, 134),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person,
                    color: Color.fromARGB(255, 0, 107, 96),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Borrowed from: ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item!.borrowedFrom!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.event,
                    color: isOverdue
                        ? Colors.red
                        : const Color.fromARGB(255, 0, 107, 96),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Due date: ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    formattedDueDate,
                    style: TextStyle(
                      fontSize: 16,
                      color: isOverdue ? Colors.red : Colors.black,
                      fontWeight:
                          isOverdue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isOverdue)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        "OVERDUE",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // Builds a row for displaying an attribute with proper formatting
  // ==========================================================================

  Widget buildAttributeRow(ItemAttribute attribute) {
    final String type = attribute.type.toLowerCase();
    String displayValue = attribute.value;
    bool isLink = type == "link";
    bool isCategory = type == "category";

    // Prepares the display value based on type
    if (isCategory) {
      displayValue = "N/A";
    } else if (type == "currency" && !displayValue.startsWith('€')) {
      try {
        double value = double.parse(displayValue);
        displayValue = '€${value.toStringAsFixed(2)}';
      } catch (e) {
        if (double.tryParse(displayValue) != null) {
          displayValue = '€$displayValue';
        }
      }
    }

    // Defines Flex Factors for width ratio
    const int nameFlexFactor = 2;
    const int valueFlexFactor = 3;
    const double columnSpacing = 8.0;

    // Builds the Row
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: nameFlexFactor,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color.fromARGB(255, 87, 143, 134),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                attribute.name,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: columnSpacing),
          Expanded(
            flex: valueFlexFactor,
            child: IgnorePointer(
              // This makes the container ignore pointer events unless it's a link
              ignoring: !isLink,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color.fromARGB(255, 87, 143, 134),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: isLink
                    ? GestureDetector(
                        onTap: () async {
                          String url = attribute.value;
                          if (!url.startsWith('http://') &&
                              !url.startsWith('https://')) {
                            url = 'https://$url';
                          }
                          try {
                            final Uri uri = Uri.parse(url);
                            // Use platform detection to determine how to open the link
                            if (kIsWeb) {
                              // Web platform: Use existing behavior
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text("Could not open link: $url")));
                              }
                            } else {
                              // Mobile platform: Show in-app browser view
                              showInAppWebView(context, uri, attribute.name);
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Invalid URL: $url")));
                          }
                        },
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            displayValue,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          displayValue,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 16,
                            color: isCategory ? Colors.grey : Colors.black87,
                            fontStyle: isCategory
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showInAppWebView(BuildContext context, Uri uri, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InAppWebViewPage(uri: uri, title: title),
      ),
    );
  }

  // ==========================================================================
  // Builds the image gallery with horizontal scrolling
  // ==========================================================================
  Widget buildItemImages() {
    if (isLoading || item == null) {
      return SizedBox(
        height: 150,
        width: double.infinity,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: 200,
      child: images.isEmpty
          ? Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(12.0),
                border:
                    Border.all(color: const Color.fromARGB(60, 255, 255, 255)),
              ),
              child: const Center(
                  child: Text(
                "No images available",
                style: TextStyle(color: Colors.white70),
              )),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              itemBuilder: (context, index) {
                try {
                  final String imageBinString = images[index].imageBin;
                  if (imageBinString.isEmpty) throw Exception('Empty image data');
                  Uint8List imageBytes = base64Decode(imageBinString);

                  return Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: GestureDetector(
                      onTap: () {
                        showImageDialog(context, imageBytes);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Container(
                          width: 170,
                          height: 200,
                          color: Colors.white,
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                  child: Icon(Icons.broken_image,
                                      size: 40, color: Colors.grey));
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        width: 130,
                        height: 130,
                        color: Colors.grey[200],
                        child: const Center(
                            child: Icon(Icons.broken_image,
                                size: 40, color: Colors.redAccent)),
                      ),
                    ),
                  );
                }
              },
            ),
    );
  }

  // ==========================================================================
  // Shows a dialog with zoomable full-screen image
  // ==========================================================================
  void showImageDialog(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return GestureDetector(
          onTap: () {
            Navigator.of(dialogContext).pop();
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.all(10),
            child: Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                        color: Colors.white.withAlpha(204),
                        padding: const EdgeInsets.all(20),
                        child: const Text(
                          "Error loading enlarged image",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red),
                        ));
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // Displays a button to get to the edition page
  // ==========================================================================
  Widget editButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 0, 150, 136),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
        ),
        label: const Text(
          "Edit Item",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        icon: const Icon(Icons.edit, color: Colors.white),
        onPressed: () async {
          if (!mounted) return;
          Navigator.of(context).pop();
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => ItemEditPage(
                itemId: widget.itemId,
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // Builds the main layout of the item view page
  // ==========================================================================
  @override
  Widget pageBody(BuildContext context) {
    if (isLoading && item == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (item == null) {
      return const Center(child: Text("Item not found"));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(padding: EdgeInsets.symmetric(vertical: 20.0)),
              Align(
                alignment: Alignment(-1, 0),
                child: GoBackButton(
                  pushedWidget: InventoryPage(),
                ),
              ),
              // Only show edit button for owned items (not borrowed)
              if (!isBorrowedItem) editButton(),
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
              const Padding(padding: EdgeInsets.symmetric(vertical: 4.0)),
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
                    flex: 3,
                    child: StaticTextBox(
                      label: "Title",
                      width: (MediaQuery.of(context).size.width - 40),
                      childText: Text(
                        nameController.text,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              StaticTextBox(
                label: "Description",
                width: MediaQuery.of(context).size.width - 40,
                childText: Text(
                  descriptionController.text,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 5),
              // For borrowed items, show borrowed info. For other items, show location.
              isBorrowedItem ? buildBorrowingInfo() : buildLocationField(),
              const SizedBox(height: 5),
              StaticTextBox(
                label: "Quantity",
                width: MediaQuery.of(context).size.width - 40,
                childText: Text(
                  quantityController.text,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              if (!isBorrowedItem)
                const Padding(padding: EdgeInsets.symmetric(vertical: 5.0)),
              // Attributes section
              if (attributes.isNotEmpty)
                const Align(
                  alignment: Alignment(-1, 0),
                  child: Text(
                    "More Info",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              attributes.isEmpty
                  ? const Align(
                      alignment: Alignment(-1, 0),
                      child: Text(
                        "",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : Column(
                      children: attributes
                          .map((attr) => buildAttributeRow(attr))
                          .toList(),
                    ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 20.0)),
            ],
          ),
        ),
      ),
    );
  }
}
