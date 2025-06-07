import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/location.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/Controller/location_controller.dart';
import 'package:my_ventory_mobile/Controller/user_controller.dart';
import 'package:my_ventory_mobile/View/Locations/location_folder_view.dart';
import 'package:my_ventory_mobile/View/Locations/location_item_view.dart';
import 'package:my_ventory_mobile/View/Locations/location_page.dart';
import 'package:my_ventory_mobile/Controller/filters_list.dart';
import 'dart:convert';
import 'dart:typed_data';

enum SortCriteria { name, createdAt, updatedAt, quantity }

enum SortDirection { ascending, descending }

class LocationDirectoryView extends StatefulWidget {
  final int userId;
  final String searchQuery;
  final Function(int locationId) onLocationSelected;

  const LocationDirectoryView({
    super.key,
    required this.userId,
    required this.searchQuery,
    required this.onLocationSelected,
  });

  @override
  LocationDirectoryViewState createState() => LocationDirectoryViewState();
}

class LocationDirectoryViewState extends State<LocationDirectoryView> {
  // Variables
  bool isLoading = true;
  List<Location> locations = [];
  List<InventoryItem> items = [];
  Map<String, List<String>> activeFilters = {};

  DateTime? selectedDateAfter;
  DateTime? selectedDateBefore;

  static const Color buttonIconColor = Color(0xFF83B8AF);
  static const Color buttonBackgroundColor = Color(0xFFE5E9E1);
  static const double buttonIconSize = 26.0;

  List<int?> navigationStack = [];
  Map<int, Location> locationCache = {};
  Location? currentLocation;
  Map<String, Location> locationNameMap = {};

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLocationsExpanded = true;

  static const Color headerButtonBackgroundColor = Color(0xFFE5E9E1);
  static const double headerButtonIconSize = 22.0;

  int? minQuantityFilter;
  int? maxQuantityFilter;
  RangeValues? selectedQuantityRange;

  SortCriteria currentSortCriteria = SortCriteria.name;
  SortDirection currentSortDirection = SortDirection.ascending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      buildLocationCache().then((_) {
        loadRootLevelContent();
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationDirectoryView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.searchQuery != oldWidget.searchQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigationStack.isNotEmpty && navigationStack.last != null) {
          loadLocationContent(navigationStack.last!);
        } else {
          loadRootLevelContent();
        }
      });
    }
  }

  // ==========================================================================
  // Builds a cache of all locations to help map location names to location objects
  Future<void> buildLocationCache() async {
    try {
      final allLocations =
          await UserController.getLocationsOfUser(widget.userId) ?? [];

      locationNameMap = {
        for (var location in allLocations) location.name.toLowerCase(): location
      };

      locationCache = {
        for (var location in allLocations) location.locationId: location
      };
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Could not load locations")));
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Loads all top-level locations (= that has no parent)
  Future<void> loadRootLevelContent() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final userLocations =
          await UserController.getLocationsOfUser(widget.userId) ?? [];
      List<Location> topLevelLocations =
          userLocations.where((loc) => loc.parentLocationId == null).toList();

      if (widget.searchQuery.isNotEmpty) {
        topLevelLocations = topLevelLocations
            .where((loc) => loc.name
                .toLowerCase()
                .contains(widget.searchQuery.toLowerCase()))
            .toList();
      }

      List<InventoryItem> rootItems = await getFilteredItems(null);

      navigationStack = [];
      currentLocation = null;

      widget.onLocationSelected(0);

      if (mounted) {
        setState(() {
          locations = topLevelLocations;
          items = rootItems;
          isLoading = false;
        });

        applySorting();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          locations = [];
          items = [];
          isLoading = false;
        });
      }
      throw Exception("Error loading root level content: $e");
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Method to get filtered items based on active filters
  Future<List<InventoryItem>> getFilteredItems(int? locationId) async {
    if (activeFilters.isEmpty &&
        widget.searchQuery.isEmpty &&
        selectedDateAfter == null &&
        selectedDateBefore == null &&
        minQuantityFilter == null &&
        maxQuantityFilter == null) {
      if (locationId == null) {
        // Root level - gets items with no location
        final allItems =
            await UserController.getItemsOfUser(widget.userId) ?? [];
        return allItems.where((item) {
          return item.location == null || item.location!.isEmpty;
        }).toList();
      } else {
        // Gets items for a specific location
        return await LocationController.getItemsInLocation(locationId) ?? [];
      }
    }

    String? locationName;
    if (locationId != null) {
      final location = locationCache[locationId];
      locationName = location?.name;
    }

    if (activeFilters.isEmpty) {
      // Create quantity filter parameters
      String? quantity;
      String? quantityMoreThan;
      String? quantityLessThan;

      if (minQuantityFilter != null &&
          maxQuantityFilter != null &&
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

      return await UserController.filterItems(
        userId: widget.userId,
        name: widget.searchQuery.isNotEmpty ? widget.searchQuery : null,
        locationName: locationName,
        createdAfter: selectedDateAfter,
        createdBefore: selectedDateBefore,
        quantity: quantity,
        quantityMoreThan: quantityMoreThan,
        quantityLessThan: quantityLessThan,
      );
    } else {
      Set<int> processedItemIds = {};
      List<InventoryItem> combinedResults = [];

      for (var entry in activeFilters.entries) {
        String attributeName = entry.key;
        List<String> attributeValues = entry.value;

        for (var attributeValue in attributeValues) {
          // Create quantity filter parameters
          String? quantity;
          String? quantityMoreThan;
          String? quantityLessThan;

          if (minQuantityFilter != null &&
              maxQuantityFilter != null &&
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

          final items = await UserController.filterItems(
            userId: widget.userId,
            name: widget.searchQuery.isNotEmpty ? widget.searchQuery : null,
            locationName: locationName,
            attributeName: attributeName,
            attributeValue: attributeValue,
            createdAfter: selectedDateAfter,
            createdBefore: selectedDateBefore,
            quantity: quantity,
            quantityMoreThan: quantityMoreThan,
            quantityLessThan: quantityLessThan,
          );

          // Adds non-duplicate items to our result list
          for (var item in items) {
            if (!processedItemIds.contains(item.itemId)) {
              processedItemIds.add(item.itemId);
              combinedResults.add(item);
            }
          }
        }
      }

      return combinedResults;
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Loads content of a specific location
  Future<void> loadLocationContent(int locationId) async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final location = await LocationController.getLocationById(locationId);

      if (location != null) {
        final sublocations =
            await LocationController.getSublocations(locationId);
        List<Location> filteredLocations = sublocations ?? [];

        if (widget.searchQuery.isNotEmpty) {
          filteredLocations = filteredLocations
              .where((loc) => loc.name
                  .toLowerCase()
                  .contains(widget.searchQuery.toLowerCase()))
              .toList();
        }

        final filteredItems = await getFilteredItems(locationId);

        currentLocation = location;
        locationCache[locationId] = location;

        // Updates navigation stack if this is a new location ID
        int existingIndex = navigationStack.indexOf(locationId);
        if (existingIndex >= 0) {
          navigationStack = navigationStack.sublist(0, existingIndex + 1);
        } else {
          navigationStack.add(locationId);
        }
        // Notifies parent about selected location
        widget.onLocationSelected(locationId);

        if (mounted) {
          setState(() {
            locations = filteredLocations;
            items = filteredItems;
            isLoading = false;
          });

          applySorting();
        }
      } else {
        // If the location is not found, goes back to root
        loadRootLevelContent();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          locations = [];
          items = [];
          isLoading = false;
        });
      }
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Handles filter selection
  void handleFilterSelection(
      String attributeName, List<String> attributeValues) {
    setState(() {
      if (attributeValues.isEmpty) {
        activeFilters.remove(attributeName);
      } else {
        activeFilters[attributeName] = attributeValues;
      }
    });

    if (navigationStack.isNotEmpty && navigationStack.last != null) {
      loadLocationContent(navigationStack.last!);
    } else {
      loadRootLevelContent();
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Handler for "Created After" date selection
  void handleDateAfterSelected(DateTime? date) {
    setState(() {
      selectedDateAfter = date;
    });

    if (navigationStack.isNotEmpty && navigationStack.last != null) {
      loadLocationContent(navigationStack.last!);
    } else {
      loadRootLevelContent();
    }
  }

  void handleDateBeforeSelected(DateTime? date) {
    setState(() {
      selectedDateBefore = date;
    });

    if (navigationStack.isNotEmpty && navigationStack.last != null) {
      loadLocationContent(navigationStack.last!);
    } else {
      loadRootLevelContent();
    }
  }
  // ==========================================================================

  // ==========================================================================
  void applySorting() {
    if (items.isEmpty) return;

    setState(() {
      items.sort((a, b) {
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
          // case SortCriteria.location:
          //   final locationA = a.location ?? "";
          //   final locationB = b.location ?? "";
          //   result = locationA.toLowerCase().compareTo(locationB.toLowerCase());
          //   break;
        }

        return currentSortDirection == SortDirection.ascending
            ? result
            : -result;
      });
    });
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
    }

    String directionText =
        currentSortDirection == SortDirection.ascending ? "↑" : "↓";
    return "$criteriaText $directionText";
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
          // case 'location':
          //   currentSortCriteria = SortCriteria.location;
          //   break;
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
  // ==========================================================================

  // ==========================================================================
  // Navigates one level up in the navigation stack.
  // - if only one location is left in the stack, it resets to the root level.
  // - otherwise, it removes the current location from the stack and loads the content of the previous location.
  void navigateUp() {
    if (navigationStack.isNotEmpty) {
      if (navigationStack.length == 1) {
        loadRootLevelContent();
      } else {
        navigationStack.removeLast();
        final previousLocationId = navigationStack.last;
        loadLocationContent(previousLocationId!);
      }
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Method to navigate to the location edit page
  void navigateToLocationEdit() {
    final int locationId = currentLocation?.locationId ?? 0;
    // Only navigate if we have a valid location (=not root)
    if (locationId > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPage(
            locationId: locationId,
          ),
        ),
      ).then((_) {
        // Refreshes data when returning from edit page
        if (currentLocation != null) {
          loadLocationContent(currentLocation!.locationId);
        } else {
          loadRootLevelContent();
        }
      });
    }
  }
  // ==========================================================================

  // ==========================================================================
  // Shows dialog to create a new location
  void showCreateLocationDialog() {
    _nameController.clear();
    _capacityController.clear();
    _descriptionController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(currentLocation == null
              ? "Create New Location"
              : "Create New Sublocation"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Name",
                    hintText: "Enter location name",
                  ),
                ),
                TextField(
                  controller: _capacityController,
                  decoration: const InputDecoration(
                    labelText: "Capacity",
                    hintText: "Enter location capacity",
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Description",
                    hintText: "Enter location description",
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                createLocation();
                Navigator.of(context).pop();
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // Method to handle quantity filter selection
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

    // Refresh the content based on current navigation
    if (navigationStack.isNotEmpty && navigationStack.last != null) {
      loadLocationContent(navigationStack.last!);
    } else {
      loadRootLevelContent();
    }
  }

  // ==========================================================================
  // Creates a new location
  Future<void> createLocation() async {
    // Validates input
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location name is required")),
      );
      return;
    }

    int capacity = 0;
    try {
      capacity = int.parse(_capacityController.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid capacity number")),
      );
      return;
    }

    final description = _descriptionController.text.trim();

    try {
      setState(() {
        isLoading = true;
      });

      final newLocation = await LocationController.createLocation(
        name: name,
        capacity: capacity,
        description: description,
        ownerId: widget.userId,
        parentLocationId: currentLocation?.locationId,
      );

      // If location creation succeeded, refreshes UI accordingly
      if (newLocation != null) {
        if (currentLocation != null) {
          loadLocationContent(currentLocation!.locationId);
        } else {
          loadRootLevelContent();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${newLocation.name} created successfully")),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to create location")),
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
      setState(() {
        isLoading = false;
      });
    }
  }
  // ==========================================================================

  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: buildLocationHeader(),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Calculate screen width for equal-sized buttons with more padding
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 96) / 2,
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
                            style:
                                TextStyle(color: Colors.black54, fontSize: 13)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8.0),

                SizedBox(
                  width: (MediaQuery.of(context).size.width - 96) / 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFE5E9E1),
                      foregroundColor: Colors.black54,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.0),
                        side: BorderSide(color: Colors.grey.shade300, width: 1),
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
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: FiltersList(
              onFilterSelected: handleFilterSelection,
              activeFilterValues: activeFilters,
              onDateAfterSelected: handleDateAfterSelected,
              onDateBeforeSelected: handleDateBeforeSelected,
              selectedDateAfter: selectedDateAfter,
              selectedDateBefore: selectedDateBefore,
              isLocationView: true,
              hideAddFilterButton: true,
              onQuantityFilterSelected: handleQuantityFilterSelected,
              selectedQuantityRange: selectedQuantityRange,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                navigationStack.isNotEmpty && navigationStack.last != null
                    ? loadLocationContent(navigationStack.last!)
                    : loadRootLevelContent(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Collapsible folders header ---
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16, top: 8, bottom: 8, right: 16),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isLocationsExpanded = !_isLocationsExpanded;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Locations ",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              if (locations.isNotEmpty)
                                Text(
                                  "(${locations.length})",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isLocationsExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.black87,
                            size: 24.0,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- Conditionally displays the LocationFolderView as a grid ---
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1.0,
                        child: child,
                      );
                    },
                    child: _isLocationsExpanded
                        ? LocationFolderView(
                            key: ValueKey(_isLocationsExpanded),
                            locations: locations,
                            onLocationSelected: (location) =>
                                loadLocationContent(location.locationId),
                          )
                        : SizedBox.shrink(key: ValueKey(_isLocationsExpanded)),
                  ),

                  // --- Item List ---
                  isLoading && items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : LocationItemView(
                          items: items,
                          locationName:
                              currentLocation?.name ?? "Default Location",
                          onRefresh: () => navigationStack.isNotEmpty &&
                                  navigationStack.last != null
                              ? loadLocationContent(navigationStack.last!)
                              : loadRootLevelContent(),
                        ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  // ==========================================================================

  // ==========================================================================
  // Builds the location header that displays count, location path, edit and create buttons etc
  Widget buildLocationHeader() {
    if (currentLocation == null) {
      // For root location, no need for FutureBuilder
      return Container(
        width: MediaQuery.of(context).size.width * 0.95,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E9E1),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                if (navigationStack.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: navigateUp,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    "My Locations",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                buildHeaderActionButton(
                  icon: Icons.add_circle_outline,
                  tooltip: "Add location",
                  iconColor: buttonIconColor,
                  backgroundColor: buttonBackgroundColor,
                  iconSize: buttonIconSize,
                  onPressed: showCreateLocationDialog,
                ),
              ],
            ),

            // Location path (using blue-green color since no image)
            if (navigationStack.isNotEmpty &&
                navigationStack.any((id) => id != null)) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    InkWell(
                      onTap: loadRootLevelContent,
                      child: const Text(
                        "My Locations",
                        style: TextStyle(
                          color: Color(0xFF83B8AF),
                        ),
                      ),
                    ),
                    for (int i = 0; i < navigationStack.length; i++)
                      if (navigationStack[i] != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Color(0xFF83B8AF),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                loadLocationContent(navigationStack[i]!);
                                if (mounted) {
                                  setState(() {
                                    navigationStack =
                                        navigationStack.sublist(0, i + 1);
                                  });
                                }
                              },
                              child: Text(
                                getLocationNameForBreadcrumb(
                                    navigationStack[i]),
                                style: const TextStyle(
                                  color: Color(0xFF83B8AF),
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return FutureBuilder<List<LocationImage>?>(
      future: LocationController.getLocationImages(currentLocation!.locationId),
      builder: (context, snapshot) {
        bool hasImage = false;
        Uint8List? imageBytes;

        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          try {
            final firstImage = snapshot.data!.first;
            if (firstImage.imageBin != null &&
                firstImage.imageBin!.isNotEmpty) {
              imageBytes = base64Decode(firstImage.imageBin!);
              hasImage = true;
            }
          } catch (e) {
            // Error handling
          }
        }

        return Container(
          width: MediaQuery.of(context).size.width * 0.95,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                if (hasImage && imageBytes != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.35,
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        hasImage ? Colors.transparent : const Color(0xFFE5E9E1),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: hasImage
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          if (navigationStack.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: navigateUp,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              currentLocation?.name ?? "My Locations",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (currentLocation != null) ...[
                            buildHeaderActionButton(
                              icon: Icons.edit,
                              tooltip: "Edit location",
                              iconColor: buttonIconColor,
                              backgroundColor: buttonBackgroundColor,
                              iconSize: buttonIconSize,
                              onPressed: navigateToLocationEdit,
                            ),
                            const SizedBox(width: 8),
                          ],
                          buildHeaderActionButton(
                            icon: Icons.add_circle_outline,
                            tooltip:
                                "Add ${currentLocation == null ? 'location' : 'sublocation'}",
                            iconColor: buttonIconColor,
                            backgroundColor: buttonBackgroundColor,
                            iconSize: buttonIconSize,
                            onPressed: showCreateLocationDialog,
                          ),
                        ],
                      ),

                      // Location path - with hasImage variable access
                      if (navigationStack.isNotEmpty &&
                          navigationStack.any((id) => id != null)) ...[
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              InkWell(
                                onTap: loadRootLevelContent,
                                child: Text(
                                  "My Locations",
                                  style: TextStyle(
                                    color: hasImage
                                        ? const Color(0xFFE0E0E0)
                                        : const Color(0xFF83B8AF),
                                  ),
                                ),
                              ),
                              for (int i = 0; i < navigationStack.length; i++)
                                if (navigationStack[i] != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Icon(
                                          Icons.chevron_right,
                                          size: 16,
                                          color: hasImage
                                              ? const Color(0xFFE0E0E0)
                                              : const Color(0xFF83B8AF),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          loadLocationContent(
                                              navigationStack[i]!);
                                          if (mounted) {
                                            setState(() {
                                              navigationStack = navigationStack
                                                  .sublist(0, i + 1);
                                            });
                                          }
                                        },
                                        child: Text(
                                          getLocationNameForBreadcrumb(
                                              navigationStack[i]),
                                          style: TextStyle(
                                            color: hasImage
                                                ? const Color(0xFFE0E0E0)
                                                : const Color(0xFF83B8AF),
                                            fontWeight:
                                                i == navigationStack.length - 1
                                                    ? FontWeight.w500
                                                    : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            ],
                          ),
                        ),
                      ],

                      // Location details
                      if (currentLocation != null) ...[
                        const SizedBox(height: 8),
                        if (currentLocation!.description != null &&
                            currentLocation!.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              currentLocation!.description!,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.black54),
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: '${currentLocation!.usedCapacity}',
                                    style: TextStyle(
                                      fontWeight: items.length >=
                                              currentLocation!.capacity
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: items.length >=
                                              currentLocation!.capacity
                                          ? Colors.orange.shade900
                                          : Colors.grey.shade800,
                                    ),
                                  ),
                                  TextSpan(
                                      text:
                                          ' / ${currentLocation!.capacity} items present in this location'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // ==========================================================================

  // ==========================================================================
  Widget buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required Color iconColor,
    required Color backgroundColor,
    required double iconSize,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(38),
              blurRadius: 3,
              offset: const Offset(0, 1),
            )
          ]),
      child: IconButton(
        icon: Icon(icon),
        iconSize: iconSize,
        color: iconColor,
        tooltip: tooltip,
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }
  // ==========================================================================

  // ==========================================================================
  String getLocationNameForBreadcrumb(int? locationId) {
    if (locationId == null) {
      return "My Locations";
    }

    final location = locationCache[locationId];
    return location?.name ?? "Unknown";
  }
  // ==========================================================================

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
}
