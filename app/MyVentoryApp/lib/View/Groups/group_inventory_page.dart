import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/Model/page_template.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';
import 'package:my_ventory_mobile/Controller/myventory_search_bar.dart';

class GroupInventoryPage extends PageTemplate {
  final int groupId;

  const GroupInventoryPage({
    super.key,
    required this.groupId,
  });

  @override
  PageTemplateState<GroupInventoryPage> createState() =>
      GroupInventoryPageState();
}

class GroupInventoryPageState extends PageTemplateState<GroupInventoryPage> {
  final ApiService _apiService = ApiService();
  List<InventoryItem> _groupItems = [];
  List<InventoryItem> _userSharedItems = [];
  List<InventoryItem> _availableItems = [];
  bool _isLoading = true;
  int? _userId;
  String _searchQuery = '';
  final Map<int, int> _itemQuantities = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _userId = await AuthService.getUserId();
      await Future.wait([
        _loadGroupInventory(),
        _loadUserSharedItems(),
        _loadAvailableItems(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Future<void> _fetchOwnerEmails() async {
  //   // No longer needed as owner emails come directly from the API response
  // }

  Future<void> _loadAvailableItems() async {
    if (_userId == null) return;

    final response = await _apiService.get('/users/$_userId/items');
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final List<dynamic> itemsJson;

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          itemsJson = responseData['data'];
        } else if (responseData.containsKey('items')) {
          itemsJson = responseData['items'];
        } else if (responseData.containsKey('results')) {
          itemsJson = responseData['results'];
        } else {
          itemsJson = [responseData];
        }
      } else if (responseData is List) {
        itemsJson = responseData;
      } else {
        throw Exception('API response has unexpected format');
      }

      setState(() {
        _availableItems =
            itemsJson.map((item) => InventoryItem.fromJson(item)).toList();
      });
    } else {
      throw Exception('Failed to load available items');
    }
  }

  Future<void> _loadGroupInventory() async {
    final response =
        await _apiService.get('/groups/${widget.groupId}/inventory');
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final List<dynamic> itemsJson;

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          itemsJson = responseData['data'];
        } else if (responseData.containsKey('items')) {
          itemsJson = responseData['items'];
        } else if (responseData.containsKey('results')) {
          itemsJson = responseData['results'];
        } else {
          itemsJson = [responseData];
        }
      } else if (responseData is List) {
        itemsJson = responseData;
      } else {
        throw Exception('API response has unexpected format');
      }

      setState(() {
        _groupItems =
            itemsJson.map((item) => InventoryItem.fromJson(item)).toList();
      });
    } else {
      throw Exception('Failed to load group inventory');
    }
  }

  Future<void> _loadUserSharedItems() async {
    if (_userId == null) return;

    final response = await _apiService
        .get('/groups/${widget.groupId}/inventory/user/$_userId');
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final List<dynamic> itemsJson;

      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data')) {
          itemsJson = responseData['data'];
        } else if (responseData.containsKey('items')) {
          itemsJson = responseData['items'];
        } else if (responseData.containsKey('results')) {
          itemsJson = responseData['results'];
        } else {
          itemsJson = [responseData];
        }
      } else if (responseData is List) {
        itemsJson = responseData;
      } else {
        throw Exception('API response has unexpected format');
      }

      setState(() {
        _userSharedItems =
            itemsJson.map((item) => InventoryItem.fromJson(item)).toList();
      });
    } else {
      throw Exception('Failed to load user shared items');
    }
  }

  bool _isItemShared(InventoryItem item) {
    return _userSharedItems
        .any((sharedItem) => sharedItem.itemId == item.itemId);
  }

  Future<void> _shareItem(InventoryItem item) async {
    if (_isItemShared(item)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('This item is already shared with the group')),
        );
      }
      return;
    }

    final sharedQuantity = _itemQuantities[item.itemId] ?? 1;
    if (sharedQuantity > item.quantity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('You can only share up to ${item.quantity} items')),
        );
      }
      return;
    }

    try {
      final response = await _apiService.post(
        '/groups/${widget.groupId}/inventory/${item.itemId}',
        {
          'itemId': item.itemId,
          'groupId': widget.groupId,
          'quantity': sharedQuantity,
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Shared $sharedQuantity ${item.name}(s) with the group')),
          );
        }
      } else {
        throw Exception('Failed to share item');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing item: $e')),
        );
      }
    }
  }

  Future<void> _removeSharedItem(InventoryItem item) async {
    try {
      final response = await _apiService.delete(
        '/groups/${widget.groupId}/inventory/${item.itemId}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item removed from group')),
          );
        }
      } else {
        throw Exception('Failed to remove item');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e')),
        );
      }
    }
  }

  void _updateQuantity(InventoryItem item, int quantity) {
    setState(() {
      _itemQuantities[item.itemId] = quantity;
    });
  }

  List<InventoryItem> get _filteredItems {
    return _availableItems.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget pageBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              IconButton(
                padding: const EdgeInsets.all(16.0),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              const Expanded(
                child: Text(
                  "Group Inventory",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Available items section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available Items',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          MyventorySearchBar(
                            userId: _userId ?? 0,
                            onSearch: (value) {
                              setState(() => _searchQuery = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_filteredItems.isEmpty)
                            const Center(child: Text('No items available'))
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = _filteredItems[index];
                                final bool isShared = _isItemShared(item);
                                final sharedQuantity = _userSharedItems
                                    .where((sharedItem) =>
                                        sharedItem.itemId == item.itemId)
                                    .fold(
                                        0,
                                        (sum, sharedItem) =>
                                            sum + sharedItem.quantity);
                                final availableQuantity =
                                    item.quantity - sharedQuantity;

                                return ListTile(
                                  title: Text(item.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Available: $availableQuantity'),
                                      if (isShared)
                                        Text('Already shared: $sharedQuantity'),
                                      if (!isShared && availableQuantity > 0)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove),
                                              onPressed: () => _updateQuantity(
                                                item,
                                                (_itemQuantities[item.itemId] ??
                                                                1) -
                                                            1 >
                                                        0
                                                    ? (_itemQuantities[
                                                                item.itemId] ??
                                                            1) -
                                                        1
                                                    : 1,
                                              ),
                                              iconSize: 20,
                                              padding: const EdgeInsets.all(4),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            Text(
                                                '${_itemQuantities[item.itemId] ?? 1}'),
                                            IconButton(
                                              icon: const Icon(Icons.add),
                                              onPressed: () => _updateQuantity(
                                                item,
                                                (_itemQuantities[item.itemId] ??
                                                                1) +
                                                            1 <=
                                                        availableQuantity
                                                    ? (_itemQuantities[
                                                                item.itemId] ??
                                                            1) +
                                                        1
                                                    : availableQuantity,
                                              ),
                                              iconSize: 20,
                                              padding: const EdgeInsets.all(4),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isShared)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8.0),
                                          child: Icon(Icons.check_circle,
                                              color: Colors.green),
                                        ),
                                      if (availableQuantity > 0)
                                        ElevatedButton(
                                          onPressed: isShared
                                              ? null
                                              : () => _shareItem(item),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isShared
                                                ? Colors.grey
                                                : const Color.fromARGB(
                                                    255, 0, 107, 96),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                          ),
                                          child: Text(
                                            isShared ? 'Shared' : 'Share',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isShared
                                                  ? Colors.black54
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Your shared items section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Shared Items',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (_userSharedItems.isEmpty)
                            const Center(child: Text('No items shared'))
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _userSharedItems.length,
                              itemBuilder: (context, index) {
                                final item = _userSharedItems[index];
                                final ownerEmail =
                                    item.ownerEmail ?? 'Email not available';
                                return ListTile(
                                  title: Text(item.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Quantity: ${item.quantity}'),
                                      Text('Owner: ${item.ownerName}'),
                                      Text('Email: $ownerEmail'),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: ElevatedButton(
                                    onPressed: () => _removeSharedItem(item),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text(
                                      'Remove',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Group inventory section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Group Inventory',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (_groupItems.isEmpty)
                            const Center(
                                child: Text('No items in group inventory'))
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _groupItems.length,
                              itemBuilder: (context, index) {
                                final item = _groupItems[index];
                                final ownerEmail =
                                    item.ownerEmail ?? 'Email not available';
                                return ListTile(
                                  title: Text(item.name),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Quantity: ${item.quantity}'),
                                      Text('Owner: ${item.ownerName}'),
                                      Text('Email: $ownerEmail'),
                                    ],
                                  ),
                                  isThreeLine: true,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
