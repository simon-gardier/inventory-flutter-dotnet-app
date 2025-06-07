import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/Controller/item_controller.dart';
import 'package:my_ventory_mobile/View/MainPages/inventory_page.dart';
import 'package:my_ventory_mobile/View/item_view_page.dart';
import 'package:shimmer/shimmer.dart';

class VerticalElementsList extends StatefulWidget {
  final bool isFirstOption;
  final List<InventoryItem> items;
  final String searchQuery;
  final int userId;
  final bool isLoading;
  final Map<int, String> lendingStatuses; // Map of itemId -> lending status

  const VerticalElementsList({
    super.key,
    required this.isFirstOption,
    required this.userId,
    this.items = const [],
    this.searchQuery = '',
    required this.isLoading,
    this.lendingStatuses = const {},
  });

  @override
  VerticalElementsListState createState() => VerticalElementsListState();
}

class VerticalElementsListState extends State<VerticalElementsList> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildShimmerEffect();
    }

    if (widget.items.isEmpty) {
      if (widget.searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.search_off, size: 64, color: Color(0xFFE5E9E1)),
              SizedBox(height: 16),
              Text("No items found",
                  style: TextStyle(fontSize: 16, color: Color(0xFFE5E9E1))),
            ],
          ),
        );
      } else {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.inventory_2_outlined,
                  size: 64, color: Color(0xFFE5E9E1)),
              SizedBox(height: 16),
              Text("Your inventory is empty",
                  style: TextStyle(fontSize: 16, color: Color(0xFFE5E9E1))),
            ],
          ),
        );
      }
    }

    if (!widget.isFirstOption) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...widget.items.map((item) => buildItemTile(context, item)),
        ],
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 60.0,
                height: 60.0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      height: 18.0,
                      color: Colors.white,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0),
                    ),
                    Container(
                      width: double.infinity,
                      height: 14.0,
                      color: Colors.white,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2.0),
                    ),
                    Container(
                      width: 40.0,
                      height: 14.0,
                      color: Colors.white,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget buildItemTile(BuildContext context, InventoryItem item) {
    final String? lendingStatus = widget.lendingStatuses[item.itemId];

    // Check if this is a borrowed item
    final bool isBorrowed = lendingStatus == 'Borrowed';

    return InkWell(
      onTap: () {
        // Capture the BuildContext before the async gap
        final BuildContext currentContext = context;
        final InventoryPageState? inventoryPageState =
            currentContext.findAncestorStateOfType<InventoryPageState>();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemViewPage(itemId: item.itemId),
          ),
        ).then((result) {
          if (result == true && mounted) {
            if (inventoryPageState != null) {
              inventoryPageState.applyFilters();
            }
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: const Border(
            top:
                BorderSide(color: Color.fromARGB(255, 203, 214, 210), width: 1),
          ),
          // Add a subtle background for borrowed items
          color: isBorrowed
              ? const Color.fromARGB(20, 30, 144, 255)
              : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            children: [
              // Item image
              SizedBox(
                width: 60,
                height: 60,
                child: isBorrowed
                    ? _buildBorrowedItemImage(item)
                    : FutureBuilder<List<ItemImage>?>(
                        future: ItemController.getItemImages(item.itemId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                width: 60.0,
                                height: 60.0,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
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
                            return const Icon(Icons.broken_image,
                                color: Colors.red);
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

              // Badge (without date now)
              if (lendingStatus != null) _buildLendingBadge(lendingStatus),

              _buildLocationIndicator(item),

              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build borrowed item image
  Widget _buildBorrowedItemImage(InventoryItem item) {
    // Only use attached images for borrowed items
    if (item.images != null && item.images!.isNotEmpty) {
      try {
        final String imageBinString = item.images!.first.imageBin;
        if (imageBinString.isNotEmpty) {
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
        }
      } catch (e) {
        // If there's an error processing the image, fall through to default
      }
    }

    // Default placeholder for borrowed items without images
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Icon(
          Icons.handshake,
          color: Colors.blue,
          size: 30,
        ),
      ),
    );
  }

  // Method to build lending status badge
  Widget _buildLendingBadge(String status) {
    Color badgeColor;
    String badgeText;

    if (status == 'Lent') {
      badgeColor = Colors.orange;
      badgeText = "L";
    } else if (status == 'Borrowed') {
      badgeColor = Colors.blue;
      badgeText = "B";
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLocationIndicator(InventoryItem item) {
    // Check if this is a borrowed item
    final String? lendingStatus = widget.lendingStatuses[item.itemId];
    final bool isBorrowed = lendingStatus == 'Borrowed';

    // For borrowed items, show the lender instead of location
    if (isBorrowed && item.borrowedFrom != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E9E1).withAlpha(128),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          "From: ${item.borrowedFrom!}",
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      );
    }

    // Regular location handling
    if (item.location != null && item.location!.isNotEmpty) {
      // We have a location, display it
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E9E1).withAlpha(128),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          item.location!,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      );
    } else {
      // No location available, show a placeholder
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          "No Location",
          style: TextStyle(
            fontSize: 12,
            color: Colors.black38,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
  }
}
