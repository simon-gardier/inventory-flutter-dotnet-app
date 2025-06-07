import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/Model/location.dart';
import 'package:my_ventory_mobile/Controller/user_controller.dart';
import 'package:my_ventory_mobile/Controller/location_controller.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';
import 'dart:convert';
import 'dart:math';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart'
    as api_service;

class FiltersList extends StatefulWidget {
  final Function(String, List<String>)? onFilterSelected;
  final Function(DateTime?)? onDateAfterSelected;
  final Function(DateTime?)? onDateBeforeSelected;
  final Function(List<int>)? onLocationFilterSelected;
  final Map<String, List<String>>? activeFilterValues;
  final DateTime? selectedDateAfter;
  final DateTime? selectedDateBefore;
  final List<int>? selectedLocationIds;
  final bool isLocationView;
  final String? selectedLendingStatus;
  final bool hasLendingItems;
  final Function(String?)? onLendingStatusSelected;
  final Function(int?, int?)? onQuantityFilterSelected;
  final RangeValues? selectedQuantityRange;
  final bool hideAddFilterButton;

  const FiltersList({
    super.key,
    this.onFilterSelected,
    this.onDateAfterSelected,
    this.onLendingStatusSelected,
    this.onDateBeforeSelected,
    this.onQuantityFilterSelected,
    this.onLocationFilterSelected,
    this.activeFilterValues,
    this.selectedDateAfter,
    this.selectedDateBefore,
    this.selectedLendingStatus,
    this.selectedQuantityRange,
    this.selectedLocationIds,
    this.isLocationView = false,
    this.hasLendingItems = false,
    this.hideAddFilterButton = false,
  });

  @override
  State<FiltersList> createState() => FiltersListState();
}

class FiltersListState extends State<FiltersList> {
  List<ItemAttribute> userAttributes = [];
  List<String> activeFilters = [];
  bool isLoading = true;
  Map<String, int> attributeCounts = {};
  bool isDateAfterActive = false;
  bool isDateBeforeActive = false;
  bool isLocationFilterActive = false;
  List<Location> userLocations = [];
  bool isLendingStatusActive = false;
  bool isQuantityFilterActive = false;
  RangeValues? selectedQuantityRange;
  double maxQuantityValue = 999.0;

  final GlobalKey _addFilterButtonKey = GlobalKey();
  final GlobalKey _locationFilterButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    fetchUserAttributes();
    fetchUserLocations();

    isDateAfterActive = widget.selectedDateAfter != null;
    isDateBeforeActive = widget.selectedDateBefore != null;
  }

  Future<void> fetchUserAttributes() async {
    try {
      final int? userId = await AuthService.getUserId();
      if (userId == null) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      final attributes = await UserController.getAttributesOfUser(userId);

      if (!mounted) return;

      if (attributes != null) {
        final uniqueAttributes = attributes.toSet().toList();
        Map<String, int> counts = {};
        for (var attr in attributes) {
          counts[attr.name] = (counts[attr.name] ?? 0) + 1;
        }

        if (mounted) {
          setState(() {
            userAttributes = uniqueAttributes;
            attributeCounts = counts;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Method to fetch user locations
  Future<void> fetchUserLocations() async {
    try {
      final int? userId = await AuthService.getUserId();
      if (userId == null) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      final response =
          await api_service.ApiService().get('/users/$userId/locations');

      // final response = await http.get(
      //   Uri.parse("${AppConfig.apiBaseUrl}/users/$userId/locations"),
      //   headers: await LocationController.getAuthHeaders(),
      // );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<Location> locations =
            data.map((json) => Location.fromJson(json)).toList();

        if (mounted) {
          setState(() {
            userLocations = locations;
          });
        }
      }
    } catch (e) {
      // print("Error fetching user locations: $e");
    }
  }

  // Method to gets all sublocations for a given location
  Future<List<Location>> getNestedLocations(int locationId) async {
    List<Location> result = [];
    try {
      final sublocations = await LocationController.getSublocations(locationId);
      if (sublocations != null) {
        result.addAll(sublocations);

        // Recursively get sublocations
        for (var sublocation in sublocations) {
          final nestedLocations =
              await getNestedLocations(sublocation.locationId);
          result.addAll(nestedLocations);
        }
      }
    } catch (e) {
      // print("Error getting nested locations: $e");
    }
    return result;
  }

  // Shows the date picker for Created After filter
  Future<void> showDateAfterPicker(BuildContext context) async {
    final initialDate = widget.selectedDateAfter ?? DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 111, 156, 149),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && widget.onDateAfterSelected != null) {
      widget.onDateAfterSelected!(pickedDate);
      setState(() {
        isDateAfterActive = true;
      });
    }
  }

  // Shows the date picker for Created Before filter
  Future<void> showDateBeforePicker(BuildContext context) async {
    final initialDate = widget.selectedDateBefore ?? DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 111, 156, 149),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && widget.onDateBeforeSelected != null) {
      widget.onDateBeforeSelected!(pickedDate);
      setState(() {
        isDateBeforeActive = true;
      });
    }
  }

  // Shows the location selection dialog
  void showLocationSelectionDialog(BuildContext context) {
    List<int> tempSelectedLocations =
        widget.selectedLocationIds?.toList() ?? [];
    bool isLoading = userLocations.isEmpty;

    if (userLocations.isEmpty) {
      fetchUserLocations();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void toggleLocationSelection(int locationId, bool isSelected) {
              setState(() {
                if (isSelected) {
                  if (!tempSelectedLocations.contains(locationId)) {
                    tempSelectedLocations.add(locationId);
                  }
                } else {
                  tempSelectedLocations.remove(locationId);
                }
              });
            }

            // Function to select location and all its sublocations
            Future<void> selectLocationWithSublocations(
                int locationId, bool isSelected) async {
              toggleLocationSelection(locationId, isSelected);

              if (isSelected) {
                try {
                  final sublocations =
                      await LocationController.getSublocations(locationId);
                  if (sublocations != null) {
                    setState(() {
                      for (var sublocation in sublocations) {
                        if (!tempSelectedLocations
                            .contains(sublocation.locationId)) {
                          tempSelectedLocations.add(sublocation.locationId);
                        }
                      }
                    });

                    // Recursively get sublocations
                    for (var sublocation in sublocations) {
                      await selectLocationWithSublocations(
                          sublocation.locationId, isSelected);
                    }
                  }
                } catch (e) {
                  // print("Error selecting sublocations: $e");
                }
              } else {
                // If deselecting, find and deselect all sublocations
                try {
                  final allSublocations = await getNestedLocations(locationId);
                  setState(() {
                    for (var sublocation in allSublocations) {
                      tempSelectedLocations.remove(sublocation.locationId);
                    }
                  });
                } catch (e) {
                  // print("Error deselecting sublocations: $e");
                }
              }
            }

            // Build the location tree with nested sublocations
            Widget buildLocationTree(Location location, bool isSelected,
                {double leftPadding = 0}) {
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.only(left: leftPadding),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            location.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (bool? value) {
                            toggleLocationSelection(
                                location.locationId, value ?? false);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.select_all, size: 18),
                          tooltip: 'Select with all sublocations',
                          onPressed: () {
                            selectLocationWithSublocations(
                                location.locationId, !isSelected);
                          },
                        ),
                      ],
                    ),
                    subtitle: location.description != null &&
                            location.description!.isNotEmpty
                        ? Text(
                            location.description!,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                  ),
                  FutureBuilder<List<Location>?>(
                    future:
                        LocationController.getSublocations(location.locationId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(left: 48.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Column(
                          children: snapshot.data!.map((sublocation) {
                            final isSubSelected = tempSelectedLocations
                                .contains(sublocation.locationId);
                            return buildLocationTree(
                              sublocation,
                              isSubSelected,
                              leftPadding: leftPadding + 16,
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              );
            }

            // Function to find top-level locations (those without parent locations)
            Future<List<Location>> getTopLevelLocations() async {
              Set<int> sublocationIds = {};

              for (var location in userLocations) {
                try {
                  final sublocations = await LocationController.getSublocations(
                      location.locationId);
                  if (sublocations != null) {
                    for (var sublocation in sublocations) {
                      sublocationIds.add(sublocation.locationId);
                    }
                  }
                } catch (e) {
                  // print("Error getting sublocations: $e");
                }
              }
              return userLocations
                  .where((loc) => !sublocationIds.contains(loc.locationId))
                  .toList();
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Text('Select Locations'),
                  const Spacer(),
                  if (isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: isLoading
                    ? const Center(child: Text('Loading locations...'))
                    : userLocations.isEmpty
                        ? const Center(child: Text('No locations available'))
                        : FutureBuilder<List<Location>>(
                            future: getTopLevelLocations(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(
                                    child: Text('No locations available'));
                              }

                              List<Location> topLevelLocations = snapshot.data!;

                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: topLevelLocations.length,
                                itemBuilder: (context, index) {
                                  final location = topLevelLocations[index];
                                  final isSelected = tempSelectedLocations
                                      .contains(location.locationId);

                                  return buildLocationTree(
                                      location, isSelected);
                                },
                              );
                            },
                          ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Clear All'),
                  onPressed: () {
                    setState(() {
                      tempSelectedLocations.clear();
                    });
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Apply'),
                  onPressed: () {
                    Navigator.of(context).pop(tempSelectedLocations);
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result != null && result is List<int>) {
        if (widget.onLocationFilterSelected != null) {
          widget.onLocationFilterSelected!(result);
          setState(() {
            isLocationFilterActive = result.isNotEmpty;
          });
        }
      }
    });
  }

  double _valueToSlider(double value) {
    return value > 0
        ? log(value + 1) / log(maxQuantityValue + 1) * maxQuantityValue
        : 0;
  }

  double _sliderToValue(double sliderValue) {
    // Inverse function of _valueToSlider
    return exp(sliderValue / maxQuantityValue * log(maxQuantityValue + 1)) - 1;
  }

  RangeValues _rangesToSlider(RangeValues ranges) {
    return RangeValues(
        _valueToSlider(ranges.start), _valueToSlider(ranges.end));
  }

  RangeValues _sliderToRanges(RangeValues sliderValues) {
    return RangeValues(
        _sliderToValue(sliderValues.start), _sliderToValue(sliderValues.end));
  }

  // Helper method to get names of selected locations
  Future<String> _getSelectedLocationNames() async {
    if (widget.selectedLocationIds == null ||
        widget.selectedLocationIds!.isEmpty) {
      return "Locations";
    }

    List<String> locationNames = [];

    for (int locationId in widget.selectedLocationIds!) {
      try {
        final location = await LocationController.getLocationById(locationId);
        if (location != null) {
          locationNames.add(location.name);
        }
      } catch (e) {
        // Placeholder
      }

      if (locationNames.length >= 2) {
        break;
      }
    }

    if (locationNames.isEmpty) {
      return "Locations (${widget.selectedLocationIds!.length})";
    } else if (locationNames.length < widget.selectedLocationIds!.length) {
      return "${locationNames.join(", ")} +${widget.selectedLocationIds!.length - locationNames.length}";
    } else {
      return locationNames.join(", ");
    }
  }

  // Method to update attributes from borrowed items
  void updateAttributesFromBorrowedItems(List<InventoryItem> borrowedItems) {
    if (borrowedItems.isEmpty) return;

    List<ItemAttribute> combinedAttributes = List.from(userAttributes);
    Map<String, int> updatedCounts = {};

    for (var attr in userAttributes) {
      if (attr.name.isNotEmpty) {
        updatedCounts[attr.name] = (updatedCounts[attr.name] ?? 0) + 1;
      }
    }

    Set<String> processedBorrowedAttributes = {};

    for (var borrowedItem in borrowedItems) {
      if (borrowedItem.attributes != null &&
          borrowedItem.attributes!.isNotEmpty) {
        for (var attr in borrowedItem.attributes!) {
          if (attr.name.isNotEmpty && attr.value.isNotEmpty) {
            String attrKey = "${attr.name}_${attr.value}";

            if (!processedBorrowedAttributes.contains(attrKey)) {
              processedBorrowedAttributes.add(attrKey);

              updatedCounts[attr.name] = (updatedCounts[attr.name] ?? 0) + 1;

              bool attributeExists = combinedAttributes.any((existingAttr) =>
                  existingAttr.name == attr.name &&
                  existingAttr.value == attr.value);

              if (!attributeExists) {
                combinedAttributes.add(attr);
              }
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        userAttributes = combinedAttributes;
        attributeCounts = updatedCounts;
      });
    }
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
                selected: widget.selectedLendingStatus == 'Active',
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
                selected: widget.selectedLendingStatus == 'Overdue',
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
                selected: widget.selectedLendingStatus == 'Returned',
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
            if (widget.selectedLendingStatus != null)
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
          widget.onLendingStatusSelected?.call(null);
          setState(() {
            isLendingStatusActive = false;
          });
        } else {
          widget.onLendingStatusSelected?.call(result as String);
          setState(() {
            isLendingStatusActive = true;
          });
        }
      }
    });
  }

  void updateMaxQuantityValue(List<InventoryItem> items) {
    if (items.isEmpty) return;

    double maxFound = 0.0;
    for (var item in items) {
      if (item.quantity > maxFound) {
        maxFound = item.quantity.toDouble();
      }
    }

    // Adds 20% buffer to max value found in items
    setState(() {
      maxQuantityValue = maxFound * 1.2;
    });
  }

  void showQuantityRangeDialog(BuildContext context) {
    RangeValues currentRealRange =
        selectedQuantityRange ?? RangeValues(0, maxQuantityValue);

    RangeValues currentSliderRange = _rangesToSlider(currentRealRange);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Converts slider values to display values
            RangeValues displayRange = _sliderToRanges(currentSliderRange);
            int minValue = displayRange.start.round();
            int maxValue = displayRange.end.round();

            return AlertDialog(
              title: const Text('Select Quantity Range'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Min: $minValue'),
                        Text('Max: $maxValue'),
                      ],
                    ),
                  ),
                  RangeSlider(
                    values: currentSliderRange,
                    min: 0,
                    max: maxQuantityValue,
                    divisions: maxQuantityValue.toInt(),
                    onChanged: (RangeValues values) {
                      setState(() {
                        currentSliderRange = values;
                      });
                    },
                    activeColor: const Color.fromARGB(255, 111, 156, 149),
                    inactiveColor: Colors.grey[300],
                  ),

                  // Displays the real value scale directly below the slider
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (int i = 0; i <= 5; i++)
                          Text(
                            '${_sliderToValue(maxQuantityValue * i / 5).round()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
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
                TextButton(
                  child: const Text('Apply'),
                  onPressed: () {
                    // Converts slider values back to real values when applying
                    Navigator.of(context)
                        .pop(_sliderToRanges(currentSliderRange));
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result != null && result is RangeValues) {
        setState(() {
          selectedQuantityRange = result;
          isQuantityFilterActive = true;
        });

        // Notifies parent about the quantity filter
        if (widget.onQuantityFilterSelected != null) {
          widget.onQuantityFilterSelected!(
              result.start.round(), result.end.round());
        }
      }
    });
  }

  Widget buildQuantityFilterButton() {
    final bool isActive = selectedQuantityRange != null;

    String rangeText = "Quantity";
    if (isActive && selectedQuantityRange != null) {
      int minValue = selectedQuantityRange!.start.round();
      int maxValue = selectedQuantityRange!.end.round();
      rangeText = "Qty: $minValue-$maxValue";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? const Color.fromARGB(255, 111, 156, 149)
              : Colors.grey[200],
          foregroundColor: isActive ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: isActive
                ? const BorderSide(
                    color: Color.fromARGB(255, 82, 114, 109), width: 1.5)
                : BorderSide.none,
          ),
        ),
        onPressed: () {
          showQuantityRangeDialog(context);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.format_list_numbered,
                size: 16, color: isActive ? Colors.white : Colors.black54),
            const SizedBox(width: 4),
            Text(
              rangeText,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black54,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: isActive
                  ? () {
                      setState(() {
                        selectedQuantityRange = null;
                        isQuantityFilterActive = false;
                      });
                      widget.onQuantityFilterSelected?.call(null, null);
                    }
                  : null,
              child: const Icon(Icons.close, size: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLendingStatusFilterButton() {
    final bool isActive = widget.selectedLendingStatus != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? const Color.fromARGB(255, 111, 156, 149)
              : Colors.grey[200],
          foregroundColor: isActive ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: isActive
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
                size: 16, color: isActive ? Colors.white : Colors.black54),
            const SizedBox(width: 4),
            Text(
              isActive
                  ? "Status: ${widget.selectedLendingStatus}"
                  : "Lending Status",
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black54,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: isActive
                  ? () {
                      setState(() {
                        isLendingStatusActive = false;
                      });
                      widget.onLendingStatusSelected?.call(null);
                    }
                  : null,
              child: const Icon(Icons.close, size: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the date filter row with fixed width buttons
  Widget buildDateFilterRow() {
    if (!isDateAfterActive && !isDateBeforeActive) {
      return const SizedBox.shrink();
    }

    final double availableWidth = MediaQuery.of(context).size.width - 24;
    final double buttonWidth = (availableWidth / 2) - 12;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isDateAfterActive)
            SizedBox(
              width: buttonWidth,
              child: buildDateFilterButton(
                'Created After',
                widget.selectedDateAfter,
                true,
                () => showDateAfterPicker(context),
                () {
                  setState(() {
                    isDateAfterActive = false;
                  });
                  widget.onDateAfterSelected?.call(null);
                },
              ),
            )
          else
            SizedBox(width: buttonWidth),
          const SizedBox(width: 8),
          if (isDateBeforeActive)
            SizedBox(
              width: buttonWidth,
              child: buildDateFilterButton(
                'Created Before',
                widget.selectedDateBefore,
                true,
                () => showDateBeforePicker(context),
                () {
                  setState(() {
                    isDateBeforeActive = false;
                  });
                  widget.onDateBeforeSelected?.call(null);
                },
              ),
            )
          else
            SizedBox(width: buttonWidth),
        ],
      ),
    );
  }

  Widget buildDateFilterButton(String title, DateTime? selectedDate,
      bool isActive, Function() onTap, Function() onClear) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive
            ? const Color.fromARGB(255, 111, 156, 149)
            : Colors.grey[200],
        foregroundColor: isActive ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: isActive
              ? const BorderSide(
                  color: Color.fromARGB(255, 82, 114, 109), width: 1.5)
              : BorderSide.none,
        ),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13.0),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isActive && selectedDate != null) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      dateFormat.format(selectedDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: GestureDetector(
              onTap: isActive ? onClear : null,
              child: const Icon(Icons.close, size: 16, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  // Method to build the location filter button
  Widget buildLocationFilterButton() {
    final bool isActive = widget.selectedLocationIds != null &&
        widget.selectedLocationIds!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton(
        key: _locationFilterButtonKey,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? const Color.fromARGB(255, 111, 156, 149)
              : Colors.grey[200],
          foregroundColor: isActive ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: isActive
                ? const BorderSide(
                    color: Color.fromARGB(255, 82, 114, 109), width: 1.5)
                : BorderSide.none,
          ),
        ),
        onPressed: () {
          showLocationSelectionDialog(context);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place,
                size: 16, color: isActive ? Colors.white : Colors.black54),
            const SizedBox(width: 4),
            isActive
                ? FutureBuilder<String>(
                    future: _getSelectedLocationNames(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text(
                          "Locations",
                          style: TextStyle(color: Colors.white),
                        );
                      }

                      return Text(
                        snapshot.data ?? "Locations",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  )
                : Text(
                    "Locations",
                    style: TextStyle(
                        color: isActive ? Colors.white : Colors.black54),
                  ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: isActive
                  ? () {
                      widget.onLocationFilterSelected?.call([]);
                      setState(() {
                        isLocationFilterActive = false;
                      });
                    }
                  : null,
              child: const Icon(Icons.close, size: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  void showValueDropdown(
      BuildContext context, String attributeName, GlobalKey key) {
    final values = userAttributes
        .where((attr) => attr.name == attributeName)
        .map((attr) => attr.value)
        .toSet()
        .toList();

    final List<String> currentValues =
        widget.activeFilterValues?[attributeName] ?? [];

    List<String> selectedValues = List.from(currentValues);

    // Builds the multi-select dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select $attributeName'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: values.map((value) {
                    return CheckboxListTile(
                      title: Text(value),
                      value: selectedValues.contains(value),
                      onChanged: (bool? isChecked) {
                        setState(() {
                          if (isChecked ?? false) {
                            if (!selectedValues.contains(value)) {
                              selectedValues.add(value);
                            }
                          } else {
                            selectedValues.remove(value);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Clear All'),
              onPressed: () {
                Navigator.of(context).pop(<String>[]);
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: const Text('Apply'),
              onPressed: () {
                Navigator.of(context).pop(selectedValues);
              },
            ),
          ],
        );
      },
    ).then((result) {
      if (result != null && result is List<String>) {
        if (widget.onFilterSelected != null) {
          widget.onFilterSelected!(attributeName, result);
        }
      }
    });
  }

  Widget buildFilterButton(String attributeName) {
    final GlobalKey key = GlobalKey();
    final List<String>? selectedValues =
        widget.activeFilterValues?[attributeName];
    final bool isActive = selectedValues != null && selectedValues.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton(
        key: key,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? const Color.fromARGB(255, 111, 156, 149)
              : Colors.grey[200],
          foregroundColor: isActive ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: isActive
                ? const BorderSide(
                    color: Color.fromARGB(255, 82, 114, 109), width: 1.5)
                : BorderSide.none,
          ),
        ),
        onPressed: () {
          showValueDropdown(context, attributeName, key);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(attributeName),
            if (isActive) ...[
              const SizedBox(width: 4),
              Text(
                "(${selectedValues.length})",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  activeFilters.remove(attributeName);
                });
                // Notifies parent about filter removal
                if (widget.onFilterSelected != null) {
                  widget.onFilterSelected!(attributeName, []);
                }
              },
              child: const Icon(Icons.close, size: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAddFilterButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton(
        key: _addFilterButtonKey,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFE5E9E1),
          foregroundColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        onPressed: () {
          showAddFilterDialog(context);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add, color: Colors.black54),
            SizedBox(width: 4),
            Text("Add filter", style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  void showAddFilterDialog(BuildContext context) {
    final uniqueAttributes =
        userAttributes.map((attr) => attr.name).toSet().toList();
    final availableAttributes = uniqueAttributes
        .where((attr) => !activeFilters.contains(attr))
        .toList();

    final List<Map<String, dynamic>> specialFilters = [
      {'name': 'Created After', 'isActive': isDateAfterActive},
      {'name': 'Created Before', 'isActive': isDateBeforeActive},
      {'name': 'Quantity', 'isActive': isQuantityFilterActive},
      if (widget.hasLendingItems)
        {'name': 'Lending Status', 'isActive': isLendingStatusActive},
      if (!widget.isLocationView)
        {'name': 'Locations', 'isActive': isLocationFilterActive},
    ];

    final List<Map<String, dynamic>> availableSpecialFilters =
        specialFilters.where((filter) => !filter['isActive']).toList();

    if (availableAttributes.isEmpty && availableSpecialFilters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All available filters are already added"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final RenderBox? buttonRenderBox =
        _addFilterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final double buttonWidth = buttonRenderBox?.size.width ?? 150.0;
    final ScrollController scrollController = ScrollController();
    final TextStyle titleStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Filter', style: titleStyle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          content: Container(
            width: buttonWidth,
            constraints: const BoxConstraints(
              maxHeight: 300,
            ),
            child: Scrollbar(
              thumbVisibility: true,
              controller: scrollController,
              child: ListView(
                controller: scrollController,
                shrinkWrap: true,
                children: [
                  if (availableSpecialFilters.isNotEmpty) ...[
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        "Special Filters",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    ...availableSpecialFilters.map((filter) => ListTile(
                          title: Text(filter['name']),
                          leading: filter['name'] == 'Locations'
                              ? const Icon(Icons.place, size: 20)
                              : filter['name'] == 'Lending Status'
                                  ? const Icon(Icons.swap_horiz, size: 20)
                                  : filter['name'] == 'Quantity'
                                      ? const Icon(Icons.format_list_numbered,
                                          size: 20)
                                      : const Icon(Icons.calendar_today,
                                          size: 20),
                          onTap: () {
                            Navigator.of(context).pop();
                            if (filter['name'] == 'Created After') {
                              showDateAfterPicker(context);
                            } else if (filter['name'] == 'Created Before') {
                              showDateBeforePicker(context);
                            } else if (filter['name'] == 'Locations') {
                              setState(() {
                                isLocationFilterActive = true;
                              });
                              showLocationSelectionDialog(context);
                            } else if (filter['name'] == 'Lending Status') {
                              setState(() {
                                isLendingStatusActive = true;
                              });
                              showLendingStatusDialog(context);
                            } else if (filter['name'] == 'Quantity') {
                              setState(() {
                                isQuantityFilterActive = true;
                              });
                              showQuantityRangeDialog(context);
                            }
                          },
                        )),
                  ],
                  if (availableAttributes.isNotEmpty) ...[
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        "Attribute Filters",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    ...availableAttributes.map((attribute) {
                      final count = attributeCounts[attribute] ?? 0;
                      return ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(attribute,
                                    overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 111, 156, 149),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          setState(() {
                            if (!activeFilters.contains(attribute)) {
                              activeFilters.add(attribute);
                            }
                          });
                          if (widget.onFilterSelected != null) {
                            widget.onFilterSelected!(attribute, []);
                          }
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    ).then((_) {
      scrollController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (!widget.hideAddFilterButton) buildAddFilterButton(),
              if (isLocationFilterActive) buildLocationFilterButton(),
              if (isQuantityFilterActive) buildQuantityFilterButton(),
              if (isLendingStatusActive && widget.hasLendingItems)
                buildLendingStatusFilterButton(),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 120.0,
                      height: 36.0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                )
              else if (userAttributes.isNotEmpty)
                ...activeFilters.map((name) => buildFilterButton(name))
              else if (!widget.hideAddFilterButton)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text("No filters available"),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        buildDateFilterRow(),
      ],
    );
  }
}
