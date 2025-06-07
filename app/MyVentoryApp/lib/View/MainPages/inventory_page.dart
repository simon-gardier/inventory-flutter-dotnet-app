import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Controller/filters_list.dart';
import 'package:my_ventory_mobile/Controller/vertical_elements_list.dart';
import 'package:my_ventory_mobile/Controller/myventory_search_bar.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/Controller/single_choice_segmented_button.dart';
import 'package:my_ventory_mobile/Controller/user_controller.dart';
import 'package:my_ventory_mobile/Controller/item_controller.dart';
import 'package:my_ventory_mobile/Controller/location_controller.dart';
import 'package:my_ventory_mobile/View/MainPages/abstract_pages_view.dart.dart';
import 'package:my_ventory_mobile/View/Locations/location_directory_view.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'dart:convert';

enum SortCriteria { name, createdAt, updatedAt, quantity, location }

enum SortDirection { ascending, descending }

// ==========================================================================
// Main inventory page widget that displays items and locations
// ==========================================================================
class InventoryPage extends AbstractPagesView {
  const InventoryPage({super.key});

  @override
  AbstractPagesViewState<InventoryPage> createState() => InventoryPageState();
}

class InventoryPageState extends AbstractPagesViewState<InventoryPage> {
  @override
  List<SegmentOption> get segmentedButtonOptions => [
        SegmentOption(label: "Items", icon: Icons.apps_outlined),
        SegmentOption(label: "Locations", icon: Icons.folder_outlined)
      ];

  @override
  List<String> get createdAttributes => ["", ""];

  Map<String, List<String>> activeFilters = {};
  List<InventoryItem> filteredItems = [];
  final FocusNode _focusNode = FocusNode();
  int? selectedLocationId;
  Map<int, String> lendingStatuses = {};
  String? selectedLendingStatus;
  List<int> selectedLocationIds = [];
  int? minQuantityFilter;
  int? maxQuantityFilter;
  RangeValues? selectedQuantityRange;

  DateTime? selectedDateAfter;
  DateTime? selectedDateBefore;
  final _apiService = ApiService();

  SortCriteria currentSortCriteria = SortCriteria.name;
  SortDirection currentSortDirection = SortDirection.ascending;

  // ==========================================================================
  // Initialize state and setup focus listeners
  // ==========================================================================
  @override
  void initState() {
    super.initState();
    isLoading = false;

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        applyFilters();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (userId != null) {
        loadLendingInfo().then((_) {
          updateUserAttributesWithBorrowedItems();
          applyFilters();
          applySorting();
        });
      } else {
        _setupUserIdListener();
      }
    });
  }

  // Listen for changes to userId
  void _setupUserIdListener() {
    // Check periodically if userId has been loaded
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        if (userId != null) {
          loadLendingInfo();
          applyFilters();
        } else {
          _setupUserIdListener();
        }
      }
    });
  }

  void handleLendingStatusSelected(String? status) {
    setState(() {
      selectedLendingStatus = status;
    });
    applyFilters();
  }

  String getLendingStatus(InventoryItem item, String? lendingStatus) {
    if (lendingStatus == null) return 'Unknown';

    if (lendingStatus == 'Lent' || lendingStatus == 'Borrowed') {
      if (item.dueDate != null && item.dueDate!.isBefore(DateTime.now())) {
        return 'Overdue';
      }
      return 'Active';
    }
    return 'Returned';
  }

  void handleQuantityFilterSelected(int? minQuantity, int? maxQuantity) {
    setState(() {
      minQuantityFilter = minQuantity;
      maxQuantityFilter = maxQuantity;

      if (minQuantity != null && maxQuantity != null) {
        selectedQuantityRange =
            RangeValues(minQuantity.toDouble(), maxQuantity.toDouble());
      } else {
        selectedQuantityRange = null;
      }
    });

    applyFilters();
  }

  // ==========================================================================
  // Load lending information for the user
  // ==========================================================================
  Future<void> loadLendingInfo() async {
    if (userId == null) return;

    try {
      final lentResponse = await _apiService.get('/users/${userId!}/lendings');
      if (lentResponse.statusCode == 200) {
        final lentData = jsonDecode(lentResponse.body);
        List<dynamic> lentItems =
            (lentData as Map<String, dynamic>)['lentItems'] ?? [];

        for (var transaction in lentItems) {
          List<dynamic> items = transaction['items'];
          bool isReturned = transaction['returnDate'] != null;

          for (var item in items) {
            int itemId = int.parse(item['itemId'].toString());
            setState(() {
              lendingStatuses[itemId] = isReturned ? 'Returned' : 'Lent';
            });
          }
        }
      }

      // Fetch borrowed items
      final borrowedResponse =
          await _apiService.get('/lendings/user/${userId!}/borrowings');
      if (borrowedResponse.statusCode == 200) {
        final List<dynamic> borrowedData = jsonDecode(borrowedResponse.body);
        List<InventoryItem> borrowedItems = [];

        // Processes borrowed items and create inventory items for them
        for (var transaction in borrowedData) {
          if (transaction['items'] != null && transaction['items'].isNotEmpty) {
            List<dynamic> items = transaction['items'];
            final String lenderName = transaction['lenderName'] ?? 'Unknown';
            final DateTime dueDate = DateTime.parse(transaction['dueDate']);
            final bool isReturned = transaction['returnDate'] != null;

            for (var item in items) {
              int itemId = int.parse(item['itemId'].toString());

              List<ItemImage>? itemImages;
              if (item['images'] != null && item['images'] is List) {
                itemImages = (item['images'] as List).map((img) {
                  return ItemImage(
                    imageId: img['imageId'] != null
                        ? int.parse(img['imageId'].toString())
                        : 0,
                    itemId: itemId,
                    imageBin: img['imageData'] ?? '',
                  );
                }).toList();
              }

              List<ItemAttribute>? itemAttributes;
              if (item['attributes'] != null &&
                  item['attributes'] is List &&
                  (item['attributes'] as List).isNotEmpty) {
                itemAttributes = (item['attributes'] as List).map((attr) {
                  return ItemAttribute(
                    attributeId: attr['attributeId'] != null
                        ? int.parse(attr['attributeId'].toString())
                        : -1,
                    type: attr['type'] ?? '',
                    name: attr['name'] ?? '',
                    value: attr['value'] ?? '',
                  );
                }).toList();

                if (item['attributeValues'] != null &&
                    item['attributeValues'] is List) {
                  for (var attrValue in item['attributeValues'] as List) {
                    if (attrValue['name'] != null &&
                        attrValue['value'] != null) {
                      itemAttributes.add(ItemAttribute(
                        attributeId: attrValue['attributeId'] != null
                            ? int.parse(attrValue['attributeId'].toString())
                            : -1,
                        type: attrValue['type'] ?? '',
                        name: attrValue['name'],
                        value: attrValue['value'],
                      ));
                    }
                  }
                }
              }

              // Creates an inventory item from the borrowed item data
              final borrowedItem = InventoryItem(
                itemId: itemId,
                name: item['itemName'] ?? 'Unknown Item',
                quantity: int.parse(item['quantity'].toString()),
                description: item['description'] ?? '',
                ownerId: int.parse(transaction['lenderId'].toString()),
                ownerName: lenderName,
                createdAt: item['createdAt'] != null
                    ? DateTime.parse(item['createdAt'])
                    : DateTime.now(),
                updatedAt: item['updatedAt'] != null
                    ? DateTime.parse(item['updatedAt'])
                    : DateTime.now(),
                borrowedFrom: lenderName,
                dueDate: dueDate,
                images: itemImages,
                attributes: itemAttributes,
              );

              // Caches the borrowed item so we don't need to fetch it again when viewing details
              ItemController.cacheBorrowedItem(borrowedItem);

              setState(() {
                lendingStatuses[itemId] = isReturned ? 'Returned' : 'Borrowed';
                borrowedItems.add(borrowedItem);
              });
            }
          }
        }

        final userItems = await UserController.getItemsOfUser(userId!) ?? [];

        // Avoids duplication by checking if item is already in the list
        final Set<int> existingItemIds =
            userItems.map((item) => item.itemId).toSet();
        final List<InventoryItem> uniqueBorrowedItems = borrowedItems
            .where((item) => !existingItemIds.contains(item.itemId))
            .toList();

        setState(() {
          filteredItems = [...userItems, ...uniqueBorrowedItems];
        });
      }
    } catch (e) {
      // Handle errors
    }
  }

  Widget buildLendingStatusFilterButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: selectedLendingStatus != null
              ? const Color.fromARGB(255, 111, 156, 149)
              : Colors.grey[200],
          foregroundColor:
              selectedLendingStatus != null ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: selectedLendingStatus != null
                ? const BorderSide(
                    color: Color.fromARGB(255, 82, 114, 109), width: 1.5)
                : BorderSide.none,
          ),
        ),
        onPressed: () {
          showLendingStatusDialog(context);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz,
                size: 16,
                color: selectedLendingStatus != null
                    ? Colors.white
                    : Colors.black54),
            const SizedBox(width: 4),
            Text(
              selectedLendingStatus != null
                  ? "Status: $selectedLendingStatus"
                  : "Lending Status",
              style: TextStyle(
                color: selectedLendingStatus != null
                    ? Colors.white
                    : Colors.black54,
                fontWeight: selectedLendingStatus != null
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: selectedLendingStatus != null
                  ? () {
                      setState(() {
                        selectedLendingStatus = null;
                      });
                      applyFilters();
                    }
                  : null,
              child: const Icon(Icons.close, size: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  void showLendingStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Lending Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Active'),
                leading: Icon(
                  Icons.calendar_today,
                  color: Colors.green,
                ),
                selected: selectedLendingStatus == 'Active',
                onTap: () {
                  Navigator.of(context).pop('Active');
                },
              ),
              ListTile(
                title: const Text('Overdue'),
                leading: Icon(
                  Icons.warning,
                  color: Colors.red,
                ),
                selected: selectedLendingStatus == 'Overdue',
                onTap: () {
                  Navigator.of(context).pop('Overdue');
                },
              ),
              ListTile(
                title: const Text('Returned'),
                leading: Icon(
                  Icons.check_circle,
                  color: Colors.grey,
                ),
                selected: selectedLendingStatus == 'Returned',
                onTap: () {
                  Navigator.of(context).pop('Returned');
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            if (selectedLendingStatus != null)
              TextButton(
                child: const Text('Clear'),
                onPressed: () {
                  Navigator.of(context).pop('clear');
                },
              ),
          ],
        );
      },
    ).then((result) {
      if (result != null) {
        if (result == 'clear') {
          handleLendingStatusSelected(null);
        } else {
          handleLendingStatusSelected(result as String);
        }
      }
    });
  }

  // ==========================================================================
  // Handles search query changes and updates filtered items
  // ==========================================================================
  @override
  void handleSearch(String query) {
    setState(() {
      currentSearchQuery = query;
    });
    applyFilters();
  }

  // ==========================================================================
  // Toggles between items and locations view
  // ==========================================================================
  @override
  void toggleView() {
    super.toggleView();

    if (isFirstSegment) {
      setState(() {
        selectedLocationId = null;
      });

      if (userId != null) {
        loadLendingInfo().then((_) {
          updateUserAttributesWithBorrowedItems();
          applyFilters();
        });
      }
    }
  }

  // ==========================================================================
  // Updates the selected location ID
  // ==========================================================================
  void handleLocationSelected(int locationId) {
    setState(() {
      selectedLocationId = locationId;
    });
  }

  // ==========================================================================
  // Updates active filters with selected attribute values
  // ==========================================================================
  void handleFilterSelection(
      String attributeName, List<String> attributeValues) {
    setState(() {
      if (attributeValues.isEmpty) {
        activeFilters.remove(attributeName);
      } else {
        activeFilters[attributeName] = attributeValues;
      }

      // This ensures borrowed items' attributes shows up in the filter dropdown
      updateUserAttributesWithBorrowedItems();
    });

    applyFilters();
  }

  // Helper method to update the user's attributes list with attributes from borrowed items
  void updateUserAttributesWithBorrowedItems() {
    List<InventoryItem> borrowedItems = filteredItems
        .where((item) => lendingStatuses[item.itemId] == 'Borrowed')
        .toList();

    if (borrowedItems.isEmpty) return;

    final horizontalList = findHorizontalElementsList();
    if (horizontalList != null) {
      horizontalList.updateAttributesFromBorrowedItems(borrowedItems);
    }
  }

  void applySorting() {
    if (filteredItems.isEmpty) return;

    setState(() {
      filteredItems.sort((a, b) {
        int result = 0;

        switch (currentSortCriteria) {
          case SortCriteria.name:
            result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            break;
          case SortCriteria.createdAt:
            result = a.createdAt.compareTo(b.createdAt);
            break;
          case SortCriteria.updatedAt:
            result = a.updatedAt.compareTo(b.updatedAt);
            break;
          case SortCriteria.quantity:
            result = a.quantity.compareTo(b.quantity);
            break;
          case SortCriteria.location:
            final locationA = a.location ?? "";
            final locationB = b.location ?? "";
            result = locationA.toLowerCase().compareTo(locationB.toLowerCase());
            break;
        }

        return currentSortDirection == SortDirection.ascending
            ? result
            : -result;
      });
    });
  }

  // Method to show the sort menu
  void showSortDialog(BuildContext context) {
    final TextStyle titleStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    );

    final TextStyle itemStyle = TextStyle(
      fontSize: 14,
      color: Colors.black87,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sort By', style: titleStyle),
          contentPadding: EdgeInsets.symmetric(vertical: 8.0),
          scrollable: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  "Sort Criteria",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              ListTile(
                dense: true,
                title: Text('Name', style: itemStyle),
                leading:
                    Icon(Icons.sort_by_alpha, size: 20, color: Colors.black54),
                trailing: currentSortCriteria == SortCriteria.name
                    ? Icon(Icons.check,
                        size: 20, color: Color.fromARGB(255, 111, 156, 149))
                    : null,
                onTap: () {
                  Navigator.of(context).pop('name');
                },
              ),
              ListTile(
                dense: true,
                title: Text('Modified', style: itemStyle),
                leading: Icon(Icons.update, size: 20, color: Colors.black54),
                trailing: currentSortCriteria == SortCriteria.updatedAt
                    ? Icon(Icons.check,
                        size: 20, color: Color.fromARGB(255, 111, 156, 149))
                    : null,
                onTap: () {
                  Navigator.of(context).pop('modified');
                },
              ),
              ListTile(
                dense: true,
                title: Text('Created', style: itemStyle),
                leading:
                    Icon(Icons.calendar_today, size: 20, color: Colors.black54),
                trailing: currentSortCriteria == SortCriteria.createdAt
                    ? Icon(Icons.check,
                        size: 20, color: Color.fromARGB(255, 111, 156, 149))
                    : null,
                onTap: () {
                  Navigator.of(context).pop('created');
                },
              ),
              ListTile(
                dense: true,
                title: Text('Quantity', style: itemStyle),
                leading: Icon(Icons.format_list_numbered,
                    size: 20, color: Colors.black54),
                trailing: currentSortCriteria == SortCriteria.quantity
                    ? Icon(Icons.check,
                        size: 20, color: Color.fromARGB(255, 111, 156, 149))
                    : null,
                onTap: () {
                  Navigator.of(context).pop('quantity');
                },
              ),
              ListTile(
                dense: true,
                title: Text('Location', style: itemStyle),
                leading: Icon(Icons.place, size: 20, color: Colors.black54),
                trailing: currentSortCriteria == SortCriteria.location
                    ? Icon(Icons.check,
                        size: 20, color: Color.fromARGB(255, 111, 156, 149))
                    : null,
                onTap: () {
                  Navigator.of(context).pop('location');
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  "Sort Direction",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              ListTile(
                dense: true,
                title: Text('Ascending', style: itemStyle),
                leading:
                    Icon(Icons.arrow_upward, size: 20, color: Colors.black54),
                trailing: currentSortDirection == SortDirection.ascending
                    ? Icon(Icons.check,
                        size: 20, color: Color.fromARGB(255, 111, 156, 149))
                    : null,
                onTap: () {
                  Navigator.of(context).pop('ascending');
                },
              ),
              ListTile(
                dense: true,
                title: Text('Descending', style: itemStyle),
                leading:
                    Icon(Icons.arrow_downward, size: 20, color: Colors.black54),
                trailing: currentSortDirection == SortDirection.descending
                    ? Icon(Icons.check,
                        size: 20, color: Color.fromARGB(255, 111, 156, 149))
                    : null,
                onTap: () {
                  Navigator.of(context).pop('descending');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    ).then((value) {
      if (value == null) return;

      setState(() {
        switch (value) {
          case 'name':
            currentSortCriteria = SortCriteria.name;
            break;
          case 'modified':
            currentSortCriteria = SortCriteria.updatedAt;
            break;
          case 'created':
            currentSortCriteria = SortCriteria.createdAt;
            break;
          case 'quantity':
            currentSortCriteria = SortCriteria.quantity;
            break;
          case 'location':
            currentSortCriteria = SortCriteria.location;
            break;
          case 'ascending':
            currentSortDirection = SortDirection.ascending;
            break;
          case 'descending':
            currentSortDirection = SortDirection.descending;
            break;
        }

        applySorting();
      });
    });
  }

  // Method to find the HorizontalElementsList widget in the widget tree
  FiltersListState? findHorizontalElementsList() {
    FiltersListState? result;
    void visitor(Element element) {
      if (element.widget is FiltersList) {
        result = (element as StatefulElement).state as FiltersListState;
      } else {
        element.visitChildren(visitor);
      }
    }

    context.visitChildElements(visitor);
    return result;
  }

  // ==========================================================================
  // Updates the "Created After" date filter and applies filters
  // ==========================================================================
  void handleDateAfterSelected(DateTime? date) {
    setState(() {
      selectedDateAfter = date;
    });
    applyFilters();
  }

  // ==========================================================================
  // Updates the "Created Before" date filter and applies filters
  // ==========================================================================
  void handleDateBeforeSelected(DateTime? date) {
    setState(() {
      selectedDateBefore = date;
    });
    applyFilters();
  }

  // ==========================================================================
  // Updates the location filter and applies filters
  // ==========================================================================
  void handleLocationFilterSelected(List<int> locationIds) {
    setState(() {
      selectedLocationIds = locationIds;
    });
    applyFilters();
  }

  // ==========================================================================
  // Helper method to get items from selected locations (no recursion)
  // ==========================================================================
  Future<List<InventoryItem>> getItemsFromSelectedLocations() async {
    List<InventoryItem> items = [];
    Set<int> processedItemIds = {};

    Map<int, String> locationNames = {};

    Future<String> getLocationName(int locationId) async {
      if (locationNames.containsKey(locationId)) {
        return locationNames[locationId]!;
      }

      try {
        final location = await LocationController.getLocationById(locationId);
        if (location != null) {
          locationNames[locationId] = location.name;
          return location.name;
        }
      } catch (e) {
        // print("Error getting location name: $e");
      }

      return "Unknown Location";
    }

    for (int locationId in selectedLocationIds) {
      try {
        final locationName = await getLocationName(locationId);

        final locationItems =
            await LocationController.getItemsInLocation(locationId);
        if (locationItems != null) {
          for (var item in locationItems) {
            if (!processedItemIds.contains(item.itemId)) {
              final itemWithLocation =
                  item.copyWith(location: locationName, locationId: locationId);

              processedItemIds.add(item.itemId);
              items.add(itemWithLocation);
            }
          }
        }
      } catch (e) {
        // print("Error getting items from location $locationId: $e");
      }
    }

    return items;
  }

  // ==========================================================================
  // Applies all active filters and updates the displayed items
  // ==========================================================================
  Future<void> applyFilters() async {
  if (userId == null) {
    return;
  }

  setState(() {
    isLoading = true;
  });

  try {
    await loadLendingInfo();
    updateUserAttributesWithBorrowedItems();

    List<InventoryItem> borrowedItems = filteredItems
        .where((item) => lendingStatuses[item.itemId] == 'Borrowed')
        .toList();
    
    List<InventoryItem> userOwnedItems = [];
    
    // Create quantity filter parameters
    String? quantity;
    String? quantityMoreThan;
    String? quantityLessThan;

    if (minQuantityFilter != null && maxQuantityFilter != null && 
        minQuantityFilter == maxQuantityFilter) {
      quantity = minQuantityFilter.toString();
    } else {
      if (minQuantityFilter != null) {
        quantityMoreThan = (minQuantityFilter! - 1).toString();
      }
      if (maxQuantityFilter != null) {
        quantityLessThan = (maxQuantityFilter! + 1).toString();
      }
    }

    if (activeFilters.isEmpty) {
      // Fetch all items with basic filters including location
      if (selectedLocationIds.isNotEmpty) {
        // Process each location
        Set<int> processedItemIds = {};
        
        for (int locationId in selectedLocationIds) {
          try {
            final location = await LocationController.getLocationById(locationId);
            if (location != null) {
              final locationItems = await UserController.filterItems(
                userId: userId!,
                name: currentSearchQuery.isNotEmpty ? currentSearchQuery : null,
                createdAfter: selectedDateAfter,
                createdBefore: selectedDateBefore,
                locationName: location.name,
                quantity: quantity,
                quantityMoreThan: quantityMoreThan,
                quantityLessThan: quantityLessThan,
              );
              
              for (var item in locationItems) {
                if (!processedItemIds.contains(item.itemId)) {
                  processedItemIds.add(item.itemId);
                  userOwnedItems.add(item.copyWith(location: location.name, locationId: locationId));
                }
              }
            }
          } catch (e) {
            // Handle error
          }
        }
      } else {
        // Regular filtering without location
        userOwnedItems = await UserController.filterItems(
          userId: userId!,
          name: currentSearchQuery.isNotEmpty ? currentSearchQuery : null,
          createdAfter: selectedDateAfter,
          createdBefore: selectedDateBefore,
          quantity: quantity,
          quantityMoreThan: quantityMoreThan,
          quantityLessThan: quantityLessThan,
        );
      }
    } else {
      // Handle attribute filters
      Set<int> processedItemIds = {};
      
      for (var entry in activeFilters.entries) {
        String attributeName = entry.key;
        List<String> attributeValues = entry.value;
        
        for (var attributeValue in attributeValues) {
          for (int locationId in selectedLocationIds.isEmpty ? [0] : selectedLocationIds) {
            try {
              String? locationName;
              if (locationId > 0) {
                final location = await LocationController.getLocationById(locationId);
                locationName = location?.name;
              }
              
              final items = await UserController.filterItems(
                userId: userId!,
                name: currentSearchQuery.isNotEmpty ? currentSearchQuery : null,
                createdAfter: selectedDateAfter,
                createdBefore: selectedDateBefore,
                locationName: locationName,
                attributeName: attributeName,
                attributeValue: attributeValue,
                quantity: quantity,
                quantityMoreThan: quantityMoreThan,
                quantityLessThan: quantityLessThan,
              );
              
              for (var item in items) {
                if (!processedItemIds.contains(item.itemId)) {
                  processedItemIds.add(item.itemId);
                  if (locationId > 0) {
                    userOwnedItems.add(item.copyWith(location: locationName, locationId: locationId));
                  } else {
                    userOwnedItems.add(item);
                  }
                }
              }
            } catch (e) {
              // Handle error
            }
          }
        }
      }
    }

      // Applies all filters to borrowed items too, including attribute filters
      List<InventoryItem> filteredBorrowedItems = borrowedItems;

      // Applies search query filter
      if (currentSearchQuery.isNotEmpty) {
        filteredBorrowedItems = filteredBorrowedItems
            .where((item) =>
                item.name
                    .toLowerCase()
                    .contains(currentSearchQuery.toLowerCase()) ||
                (item.description.isNotEmpty &&
                    item.description
                        .toLowerCase()
                        .contains(currentSearchQuery.toLowerCase())) ||
                (item.borrowedFrom != null &&
                    item.borrowedFrom!
                        .toLowerCase()
                        .contains(currentSearchQuery.toLowerCase())))
            .toList();
      }

      // Applies date filters if active
      if (selectedDateAfter != null) {
        filteredBorrowedItems = filteredBorrowedItems
            .where((item) => item.createdAt.isAfter(selectedDateAfter!))
            .toList();
      }

      if (selectedDateBefore != null) {
        filteredBorrowedItems = filteredBorrowedItems
            .where((item) => item.createdAt.isBefore(selectedDateBefore!))
            .toList();
      }

      if (minQuantityFilter != null || maxQuantityFilter != null) {
        filteredBorrowedItems = filteredBorrowedItems.where((item) {
          if (minQuantityFilter != null && item.quantity < minQuantityFilter!) {
            return false;
          }
          if (maxQuantityFilter != null && item.quantity > maxQuantityFilter!) {
            return false;
          }
          return true;
        }).toList();
      }

      if (selectedLocationIds.isNotEmpty) {
        filteredBorrowedItems = filteredBorrowedItems
            .where((item) =>
                item.locationId != null &&
                selectedLocationIds.contains(item.locationId))
            .toList();
      }

      if (activeFilters.isNotEmpty) {
        filteredBorrowedItems = filteredBorrowedItems.where((item) {
          if (item.attributes == null || item.attributes!.isEmpty) {
            return false;
          }

          for (var entry in activeFilters.entries) {
            String attributeName = entry.key;
            List<String> attributeValues = entry.value;

            bool hasMatchingAttribute = false;

            for (var attr in item.attributes!) {
              if (attr.name == attributeName &&
                  attributeValues.contains(attr.value)) {
                hasMatchingAttribute = true;
                break;
              }
            }

            if (!hasMatchingAttribute) {
              return false;
            }
          }

          return true;
        }).toList();
      }

      List<InventoryItem> combinedItems = [
        ...userOwnedItems,
        ...filteredBorrowedItems
      ];

      if (selectedLendingStatus != null) {
        List<InventoryItem> lendingFilteredItems = [];
        for (var item in combinedItems) {
          String itemStatus =
              getLendingStatus(item, lendingStatuses[item.itemId]);
          if (itemStatus == selectedLendingStatus) {
            lendingFilteredItems.add(item);
          }
        }
        combinedItems = lendingFilteredItems;
      }

      setState(() {
        filteredItems = combinedItems;
        isLoading = false;
      });

      applySorting();
    } catch (e) {
      setState(() {
        isLoading = false;
        filteredItems = [];
      });
      // print("Error applying filters: $e");
    }
  }

  Widget buildSortButton() {
    // Determines the sort text based on current criteria and direction
    String getSortText() {
      String criteriaText;
      switch (currentSortCriteria) {
        case SortCriteria.name:
          criteriaText = "Name";
          break;
        case SortCriteria.createdAt:
          criteriaText = "Created";
          break;
        case SortCriteria.updatedAt:
          criteriaText = "Modified";
          break;
        case SortCriteria.quantity:
          criteriaText = "Quantity";
          break;
        case SortCriteria.location:
          criteriaText = "Location";
          break;
      }

      String directionText =
          currentSortDirection == SortDirection.ascending ? "↑" : "↓";
      return "$criteriaText $directionText";
    }

    return Padding(
      padding:
          const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 245, 245, 245),
              foregroundColor: Colors.black87,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
                side: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => showSortDialog(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 14),
                const SizedBox(width: 4),
                Text(
                  "Sort: ${getSortText()}",
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Cleans up resources when widget is destroyed
  // ==========================================================================
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String getSortText() {
    String criteriaText;
    switch (currentSortCriteria) {
      case SortCriteria.name:
        criteriaText = "Name";
        break;
      case SortCriteria.createdAt:
        criteriaText = "Created";
        break;
      case SortCriteria.updatedAt:
        criteriaText = "Modified";
        break;
      case SortCriteria.quantity:
        criteriaText = "Quantity";
        break;
      case SortCriteria.location:
        criteriaText = "Location";
        break;
    }

    String directionText =
        currentSortDirection == SortDirection.ascending ? "↑" : "↓";
    return "$criteriaText $directionText";
  }

  // ==========================================================================
  // Builds the main UI for the inventory page
  // ==========================================================================
  @override
  Widget pageBody(BuildContext context) {
    if (userId == null) {
      return Center(child: CircularProgressIndicator());
    }

    // Calculates screen width for equal-sized buttons with more padding
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth - 96) / 2;

    return Align(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30.0, left: 8.0, right: 8.0),
            child: SingleChoiceSegmentedButton(
                onSegmentButtonChange: toggleView,
                options: segmentedButtonOptions),
          ),
          MyventorySearchBar(
            userId: userId ?? -1,
            onSearch: handleSearch,
          ),

          if (isFirstSegment)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: buttonWidth,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFE5E9E1),
                          foregroundColor: Colors.black54,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                        ),
                        onPressed: () {
                          final horizontalList = findHorizontalElementsList();
                          if (horizontalList != null) {
                            horizontalList.showAddFilterDialog(context);
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add, color: Colors.black54, size: 18),
                            SizedBox(width: 4),
                            Text("Add filter",
                                style: TextStyle(
                                    color: Colors.black54, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    SizedBox(
                      width: buttonWidth,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFE5E9E1),
                          foregroundColor: Colors.black54,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.0),
                            side: BorderSide(
                                color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                        onPressed: () => showSortDialog(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sort, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              "Sort: ${getSortText()}",
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Filters display
          if (isFirstSegment)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: FiltersList(
                onFilterSelected: handleFilterSelection,
                onDateAfterSelected: handleDateAfterSelected,
                onDateBeforeSelected: handleDateBeforeSelected,
                onLocationFilterSelected: handleLocationFilterSelected,
                onLendingStatusSelected: handleLendingStatusSelected,
                onQuantityFilterSelected: handleQuantityFilterSelected,
                activeFilterValues: activeFilters,
                selectedDateAfter: selectedDateAfter,
                selectedDateBefore: selectedDateBefore,
                selectedLocationIds: selectedLocationIds,
                selectedLendingStatus: selectedLendingStatus,
                selectedQuantityRange: selectedQuantityRange,
                hasLendingItems: lendingStatuses.isNotEmpty,
                hideAddFilterButton: true,
              ),
            ),

          if (isFirstSegment) const SizedBox(height: 8),

          Expanded(
            child: isFirstSegment
                ? VerticalElementsList(
                    userId: userId!,
                    isFirstOption: true,
                    searchQuery: currentSearchQuery,
                    items: filteredItems,
                    isLoading: isLoading,
                    lendingStatuses: lendingStatuses,
                  )
                : LocationDirectoryView(
                    userId: userId!,
                    searchQuery: currentSearchQuery,
                    onLocationSelected: handleLocationSelected,
                  ),
          ),
        ],
      ),
    );
  }
}
