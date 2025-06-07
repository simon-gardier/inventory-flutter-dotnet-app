import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CustomLocationSelector extends StatefulWidget {
  final String currentLocation;
  final List<String> locations;
  final Function(String) onLocationSelected;
  final double width;

  const CustomLocationSelector({
    super.key,
    required this.currentLocation,
    required this.locations,
    required this.onLocationSelected,
    required this.width,
  });

  @override
  State<CustomLocationSelector> createState() => _CustomLocationSelectorState();
}

class _CustomLocationSelectorState extends State<CustomLocationSelector> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final _selectorKey = GlobalKey();
  bool _isOpen = false;
  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    super.dispose();
  }

  void _toggleLocationSelector() {
    if (_isOpen) {
      closeOverlay();
    } else {
      showLocationSelector();
    }
  }

  void showLocationSelector() {
    if (!_mounted) return; // Safety check

    // Close any existing overlay first
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);

    if (mounted) {
      setState(() {
        _isOpen = true;
      });
    }
  }

  void closeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }

    // Only update state if still mounted
    if (_mounted && mounted) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox =
        _selectorKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    // Filter out "Choose a Location" from the locations list, but keep other locations
    List<String> displayLocations = [""]; // Add blank option as first item
    displayLocations.addAll(
        widget.locations.where((loc) => loc != "Choose a Location").toList());

    final double itemHeight = 35.0;
    final double gridHeight = itemHeight * 5 + 16;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Add an invisible full-screen layer to detect taps outside
          Positioned.fill(
            child: GestureDetector(
              onTap: closeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // The actual dropdown menu
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height,
            width: widget.width,
            child: Material(
              elevation: 4.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                      color: const Color.fromARGB(255, 87, 143, 134)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scrollable grid of locations
                    if (kIsWeb)
                    SizedBox(
                      height: gridHeight,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 10,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: displayLocations.length,
                        itemBuilder: (context, index) {
                          return _buildLocationGridItem(
                              displayLocations[index]);
                        },
                      ),
                    ),
                    if (!kIsWeb)
                    SizedBox(
                      height: gridHeight,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 5,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: displayLocations.length,
                        itemBuilder: (context, index) {
                          return _buildLocationGridItem(
                              displayLocations[index]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationGridItem(String location) {
    final bool isCurrentLocation = location == widget.currentLocation;

    return InkWell(
      onTap: () {
        widget.onLocationSelected(location);
        closeOverlay();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentLocation
              ? const Color.fromARGB(255, 87, 143, 134).withAlpha(51)
              : Colors.white,
          border: Border.all(
            color: isCurrentLocation
                ? const Color.fromARGB(255, 87, 143, 134)
                : Colors.grey.shade300,
            width: isCurrentLocation ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(3), // Smaller radius
        ),
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4), // Minimal padding
            child: Text(
              location.isEmpty ? "None" : location,
              style: TextStyle(
                fontWeight:
                    isCurrentLocation ? FontWeight.bold : FontWeight.normal,
                fontSize: 16, // Increased font size
                color: isCurrentLocation
                    ? const Color.fromARGB(255, 87, 143, 134)
                    : location.isEmpty
                        ? Colors.black54
                        : Colors.black87,
                fontStyle:
                    location.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Display actual location name if available, otherwise default text
    String displayText = widget.currentLocation;
    if (displayText.isEmpty) {
      displayText = "No location";
    } else if (displayText == "Choose a Location") {
      displayText = "Select a location";
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleLocationSelector,
        child: Container(
          key: _selectorKey,
          width: widget.width,
          height: 55,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color.fromARGB(255, 87, 143, 134),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 16,
                      color: displayText == "Select a location"
                          ? Colors.black54
                          : Colors.black87,
                      fontStyle: displayText == "Select a location"
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: const Color.fromARGB(255, 87, 143, 134),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
