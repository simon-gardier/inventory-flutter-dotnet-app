import 'dart:async';
import 'package:flutter/material.dart';

class MyventorySearchBar extends StatefulWidget {
  final int userId;
  final Function(String) onSearch;

  const MyventorySearchBar({
    super.key,
    required this.userId,
    required this.onSearch,
  });

  @override
  State<MyventorySearchBar> createState() => MyventorySearchBarState();
}

class MyventorySearchBarState extends State<MyventorySearchBar> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Debounced search function
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch(query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SearchBar(
        controller: _searchController,
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: 16.0),
        ),
        onChanged: _onSearchChanged,
        leading: const Icon(Icons.search),
        hintText: "Search",
      ),
    );
  }
}
