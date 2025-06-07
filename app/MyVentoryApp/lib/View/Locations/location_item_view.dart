import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/Controller/item_controller.dart';
import 'package:intl/intl.dart';
import 'package:my_ventory_mobile/View/item_view_page.dart'; // Add date formatting

class LocationItemView extends StatelessWidget {
  final List<InventoryItem> items;
  final String locationName;
  final VoidCallback onRefresh;

  const LocationItemView({
    super.key,
    required this.items,
    required this.locationName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return buildEmptyView();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add a header for the items section
        Padding(
          padding:
              const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Items ",
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              Text(
                "(${items.length})",
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => buildItemTile(context, item)),
      ],
    );
  }

  // ==========================================================================
  // Returns a widget displaying a message and icon when no items are available in the location
  Widget buildEmptyView() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 64, color: Color(0xFFE5E9E1)),
            const SizedBox(height: 16),
            Text(
              "No items in $locationName",
              style: const TextStyle(fontSize: 16, color: Color(0xFFE5E9E1)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  // ==========================================================================

  // ==========================================================================
  // Returns a clickable tile displaying item details, including image, name, quantity, description, and creation date.
  Widget buildItemTile(BuildContext context, InventoryItem item) {
    final DateFormat dateFormat = DateFormat('dd/MM/yy');
    final String createdDate = dateFormat.format(item.createdAt);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemViewPage(itemId: item.itemId),
          ),
        ).then((_) => onRefresh());
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            top:
                BorderSide(color: Color.fromARGB(255, 203, 214, 210), width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            children: [
              // Item Image
              SizedBox(
                width: 60,
                height: 60,
                child: FutureBuilder<List<ItemImage>?>(
                  future: ItemController.getItemImages(item.itemId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2));
                    }

                    if (snapshot.hasError ||
                        snapshot.data == null ||
                        snapshot.data!.isEmpty) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.grey),
                      );
                    }

                    try {
                      final String imageBinString =
                          snapshot.data!.first.imageBin;
                      if (imageBinString.isEmpty) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.grey),
                        );
                      }

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(
                          base64Decode(imageBinString),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.red,
                          ),
                        ),
                      );
                    } catch (e) {
                      return const Icon(Icons.broken_image, color: Colors.red);
                    }
                  },
                ),
              ),

              // Item details
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Quantity: ${item.quantity}",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFE0E0E0),
                      ),
                    ),
                    if (item.description.isNotEmpty)
                      Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFE0E0E0),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Date in its own column
              Container(
                padding: const EdgeInsets.only(left: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range,
                            size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          createdDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
  // ==========================================================================
}
