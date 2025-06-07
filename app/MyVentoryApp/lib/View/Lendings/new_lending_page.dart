import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/Model/page_template.dart';
import 'dart:convert';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'package:my_ventory_mobile/Controller/myventory_search_bar.dart';
import 'package:my_ventory_mobile/Model/user.dart';

class NewLendingPage extends PageTemplate {
  final int userId;

  const NewLendingPage({
    super.key,
    required this.userId,
  });

  @override
  PageTemplateState<NewLendingPage> createState() => NewLendingPageState();
}

class NewLendingPageState extends PageTemplateState<NewLendingPage> {
  final _formKey = GlobalKey<FormState>();
  final _borrowerNameController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  final List<InventoryItem> _selectedItems = [];
  final List<InventoryItem> _availableItems = [];
  final Map<int, int> _itemQuantities = {};
  String _searchQuery = '';
  final _apiService = ApiService();
  List<UserAccount> _searchedUsers = [];
  UserAccount? _selectedUser;

  @override
  void initState() {
    super.initState();
    _loadAvailableItems();
  }

  Future<void> _loadAvailableItems() async {
    try {
      final response = await _apiService.get('/users/${widget.userId}/items');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        List<dynamic> itemsJson;

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
          _availableItems.clear();
          _availableItems.addAll(itemsJson
              .map((json) => InventoryItem.fromJson(json))
              .where((item) => item.quantity > 0));
        });
      } else {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Failed to load items: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  List<InventoryItem> get _filteredItems {
    return _availableItems.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchedUsers = [];
      });
      return;
    }

    try {
      final response = await _apiService.get('/users/search');

      if (response.statusCode == 200) {
        final List<dynamic> usersJson = jsonDecode(response.body);
        final List<UserAccount> allUsers = usersJson
            .map((json) => UserAccount(
                  userId: json['userId'],
                  userName: json['username'],
                  firstName: json['firstName'],
                  lastName: json['lastName'],
                  email: json['email'],
                  passwordHash: '',
                  createdAt: DateTime.parse(json['createdAt']),
                  updatedAt: DateTime.parse(json['updatedAt']),
                ))
            .toList();

        setState(() {
          _searchedUsers = allUsers
              .where((user) =>
                  user.userName.toLowerCase().contains(query.toLowerCase()))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _selectedItems.isNotEmpty) {
      try {
        final requestBody = {
          'lenderId': widget.userId,
          'borrowerName': _borrowerNameController.text,
          if (_selectedUser != null) 'borrowerId': _selectedUser!.userId,
            'dueDate': _dueDate.add(const Duration(days: 1)).toUtc().toIso8601String(),
          'items': _selectedItems
              .map((item) => {
                    'itemId': item.itemId,
                    'quantity': _itemQuantities[item.itemId] ?? 1,
                  })
              .toList(),
        };

        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);

        final response = await _apiService.post(
          '/lendings',
          jsonEncode(requestBody),
        );

        if (!mounted) return;

        if (response.statusCode == 201) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Lending created successfully')),
          );
          // Return true to indicate that the lending page should be refreshed
          navigator.pop(true);
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
                content:
                    Text('Failed to create lending: ${response.statusCode}')),
          );
          navigator.pop(true);
        }
      } catch (e) {
        if (!mounted) return;

        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _addItem(InventoryItem item) {
    setState(() {
      if (!_selectedItems.contains(item)) {
        _selectedItems.add(item);
        _itemQuantities[item.itemId] = 1;
      }
    });
  }

  void _removeItem(InventoryItem item) {
    setState(() {
      _selectedItems.remove(item);
      _itemQuantities.remove(item.itemId);
    });
  }

  void _updateQuantity(InventoryItem item, int quantity) {
    setState(() {
      _itemQuantities[item.itemId] = quantity;
    });
  }

  @override
  Widget pageBody(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 131, 184, 175),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 87, 143, 134),
        title: const Text('New Lending', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Borrower information
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Borrower Information',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _borrowerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Borrower Name',
                          labelStyle:
                              TextStyle(color: Color.fromARGB(255, 51, 75, 71)),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Color.fromARGB(255, 51, 75, 71)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Color.fromARGB(255, 51, 75, 71)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Color.fromARGB(255, 51, 75, 71)),
                          ),
                          prefixIcon: Icon(Icons.person,
                              color: Color.fromARGB(255, 51, 75, 71)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(
                            color: Color.fromARGB(255, 51, 75, 71)),
                        onChanged: (value) {
                          _searchUsers(value);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the borrower name';
                          }
                          return null;
                        },
                      ),
                      if (_searchedUsers.isNotEmpty)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          margin: const EdgeInsets.only(top: 8),
                          child: ListView.builder(
                            itemCount: _searchedUsers.length,
                            itemBuilder: (context, index) {
                              final user = _searchedUsers[index];
                              return ListTile(
                                title: Text(user.userName),
                                subtitle:
                                    Text('${user.firstName} ${user.lastName}'),
                                onTap: () {
                                  setState(() {
                                    _selectedUser = user;
                                    _borrowerNameController.text =
                                        user.userName;
                                    _searchedUsers = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      if (_selectedUser != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Chip(
                            label: Text(_selectedUser!.userName),
                            onDeleted: () {
                              setState(() {
                                _selectedUser = null;
                                _borrowerNameController.clear();
                              });
                            },
                          ),
                        ),
                      ListTile(
                        title: const Text('Due Date',
                            style: TextStyle(
                                color: Color.fromARGB(255, 51, 75, 71))),
                        subtitle: Text(
                          _dueDate.toString().split(' ')[0],
                          style: const TextStyle(
                              color: Color.fromARGB(255, 51, 75, 71)),
                        ),
                        leading: const Icon(Icons.calendar_today,
                            color: Color.fromARGB(255, 51, 75, 71)),
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(
                              color: Color.fromARGB(255, 51, 75, 71)),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _dueDate = picked);
                          }
                        },
                      ),
                      MyventorySearchBar(
                        userId: widget.userId,
                        onSearch: (value) {
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Available Items',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = _filteredItems[index];
                                return ListTile(
                                  title: Text(item.name),
                                  subtitle: Text('Available: ${item.quantity}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => _addItem(item),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Selected Items',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _selectedItems.length,
                              itemBuilder: (context, index) {
                                final item = _selectedItems[index];
                                return ListTile(
                                  title: Text(item.name),
                                  subtitle: LayoutBuilder(
                                      builder: (context, constraints) {
                                    return Row(
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
                                                  : 1),
                                          iconSize: 20,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                            '${_itemQuantities[item.itemId] ?? 1}'),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: () => _updateQuantity(
                                              item,
                                              (_itemQuantities[item.itemId] ??
                                                              1) +
                                                          1 <=
                                                      item.quantity
                                                  ? (_itemQuantities[
                                                              item.itemId] ??
                                                          1) +
                                                      1
                                                  : item.quantity),
                                          iconSize: 20,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    );
                                  }),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _removeItem(item),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Create Lending'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
