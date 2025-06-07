import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Controller/single_choice_segmented_button.dart';
import 'package:my_ventory_mobile/Controller/myventory_search_bar.dart';
import 'package:my_ventory_mobile/Model/lending.dart' as lending_model;
import 'package:my_ventory_mobile/Model/user.dart';
import 'package:my_ventory_mobile/Model/item.dart';
import 'package:my_ventory_mobile/View/MainPages/abstract_pages_view.dart.dart';
import 'package:my_ventory_mobile/View/Lendings/lending_record_page.dart';
import 'package:my_ventory_mobile/View/Lendings/new_lending_page.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'dart:convert';

class LendingsPage extends AbstractPagesView {
  const LendingsPage({super.key});

  @override
  AbstractPagesViewState<LendingsPage> createState() => LendingsPageState();
}

class LendingsPageState extends AbstractPagesViewState<LendingsPage> {
  final _apiService = ApiService();
  List<lending_model.Lending> _lendings = [];
  String _selectedStatus = 'All';
  final List<String> _statusOptions = [
    'All',
    'In Progress',
    'Due Soon',
    'Due',
    'Finished'
  ];
  // Emails now come directly from the API response

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserIdAndLoadLendings();
    });
  }

  void _checkUserIdAndLoadLendings() {
    if (mounted) {
      if (userId != null) {
        _loadLendings();
      } else {
        Future.delayed(Duration(milliseconds: 100), () {
          _checkUserIdAndLoadLendings();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant LendingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (userId != null && _lendings.isEmpty) {
      _loadLendings();
    }
  }

  // Listens to changes in the parent state
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (userId != null && _lendings.isEmpty) {
      _loadLendings();
    }
  }

  Future<void> _loadLendings() async {
    // Check if userId is null or invalid
    if (userId == null || userId! <= 0) {
      return;
    }

    // Set loading state
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    // Emails now come directly from the API response

    try {
      final endpoint = isFirstSegment
          ? '/users/${userId!}/lendings'
          : '/lendings/user/${userId!}/borrowings';
      final response = await _apiService.get(endpoint);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> items;

        if (isFirstSegment) {
          items = (responseData as Map<String, dynamic>)['lentItems'] ?? [];
        } else {
          items = responseData as List<dynamic>;
        }

        final List<lending_model.Lending> lendings =
            items.map<lending_model.Lending>((item) {
          final lender = UserAccount(
            userId: int.parse(item['lenderId'].toString()),
            userName: item['lenderName'] ?? '',
            firstName: '',
            lastName: '',
            email: '',
            passwordHash: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Convert items to ItemLending format
          final List<lending_model.ItemLending> lendItems =
              (item['items'] as List<dynamic>).map((itemData) {
            final lending = lending_model.Lending(
              transactionId: int.parse(item['transactionId'].toString()),
              borrowerId: item['borrowerId'] != null
                  ? int.parse(item['borrowerId'].toString())
                  : null,
              borrowerName: item['borrowerName'] ?? '',
              borrowerEmail: item['borrowerEmail'],
              lenderId: int.parse(item['lenderId'].toString()),
              lenderName: item['lenderName'] ?? '',
              lenderEmail: item['lenderEmail'],
              dueDate: DateTime.parse(item['dueDate']),
              lendingDate: DateTime.parse(item['lendingDate']),
              lender: lender,
              isFinished: item['returnDate'] != null,
            );

            final inventoryItem = InventoryItem(
              itemId: int.parse(itemData['itemId'].toString()),
              name: itemData['itemName'] ?? '',
              quantity: int.parse(itemData['quantity'].toString()),
              description: '',
              ownerId: int.parse(item['lenderId'].toString()),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              ownerName: item['lenderName'] ?? 'Unknown',
            );

            return lending_model.ItemLending(
              transactionId: int.parse(item['transactionId'].toString()),
              itemId: int.parse(itemData['itemId'].toString()),
              quantity: int.parse(itemData['quantity'].toString()),
              lending: lending,
              item: inventoryItem,
            );
          }).toList();

          return lending_model.Lending(
            transactionId: int.parse(item['transactionId'].toString()),
            borrowerId: item['borrowerId'] != null
                ? int.parse(item['borrowerId'].toString())
                : null, // Handle null borrowerId
            borrowerName: item['borrowerName'] ?? '',
            borrowerEmail: item['borrowerEmail'],
            lenderId: int.parse(item['lenderId'].toString()),
            lenderName: item['lenderName'] ?? '',
            lenderEmail: item['lenderEmail'],
            dueDate: DateTime.parse(item['dueDate']),
            lendingDate: DateTime.parse(item['lendingDate']),
            lendItems: lendItems,
            lender: lender,
            isFinished: item['returnDate'] != null,
          );
        }).toList();

        setState(() {
          _lendings = lendings;
          isLoading = false;
        });

        // Emails now come directly from the API response
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Failed to load lendings: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lendings: $e')),
        );
      }
    }
  }

  @override
  void toggleView() {
    super.toggleView();
    _loadLendings();
  }

  @override
  List<SegmentOption> get segmentedButtonOptions => [
        SegmentOption(label: "Lendings", icon: Icons.share),
        SegmentOption(label: "Borrowings", icon: Icons.handshake)
      ];

  @override
  List<String> get createdAttributes => ["lending", ""];

  @override
  Widget addElementInListButton(BuildContext context, String createdAttribute) {
    // Check if userId is null or if createdAttribute is empty
    if (createdAttribute.isEmpty || userId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            foregroundColor: const Color.fromARGB(255, 51, 75, 71),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NewLendingPage(userId: userId!),
              ),
            ).then((refreshNeeded) {
              if (refreshNeeded == true) {
                _loadLendings();
              }
            });
          },
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            "Create a new $createdAttribute",
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }

  String _getLendingStatus(lending_model.Lending lending) {
    if (lending.isFinished ?? false) {
      return 'Finished';
    } else if (lending.dueDate.isBefore(DateTime.now())) {
      return 'Due';
    } else if (lending.dueDate.difference(DateTime.now()).inDays <= 7) {
      return 'Due Soon';
    } else {
      return 'In Progress';
    }
  }

  @override
  Widget pageBody(BuildContext context) {
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    child: MyventorySearchBar(
                      userId: userId!,
                      onSearch: handleSearch,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      dropdownColor: Colors.white,
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Color.fromARGB(255, 51, 75, 71)),
                      underline: Container(),
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            status,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 51, 75, 71),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedStatus = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          addElementInListButton(context,
              isFirstSegment ? createdAttributes[0] : createdAttributes[1]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 5.0)),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _lendings.where((lending) {
                  final matchesSearch = lending.borrowerName
                          .toLowerCase()
                          .contains(currentSearchQuery.toLowerCase()) ||
                      lending.lendItems?.any((item) => item.item.name
                              .toLowerCase()
                              .contains(currentSearchQuery.toLowerCase())) ==
                          true;

                  final matchesStatus = _selectedStatus == 'All' ||
                      _getLendingStatus(lending) == _selectedStatus;

                  return matchesSearch && matchesStatus;
                }).map((lending) {
                  final status = _getLendingStatus(lending);
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              LendingRecordPage(lending: lending),
                        ),
                      ).then((_) {
                        _loadLendings();
                      });
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.rectangle,
                        border: Border(
                          top: BorderSide(
                              color: Color.fromARGB(255, 203, 214, 210)),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          isFirstSegment
                                              ? 'Lent to ${lending.borrowerName} ${lending.borrowerEmail?.isNotEmpty == true ? "(${lending.borrowerEmail})" : ""}'
                                              : 'Borrowed from ${lending.lenderName} (${lending.lenderEmail?.isNotEmpty == true ? lending.lenderEmail : "Email not available"})',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Items: ${lending.lendItems?.map((item) => item.item.name).join(", ") ?? ""}',
                                    style: const TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Due: ${lending.dueDate.toString().split(" ")[0]}',
                                    style: TextStyle(
                                      color: lending.isFinished ?? false
                                          ? Colors.grey.shade300
                                          : lending.dueDate
                                                  .isBefore(DateTime.now())
                                              ? Colors.red.shade300
                                              : Colors.white,
                                    ),
                                  )
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'Finished'
                                    ? Colors.grey
                                    : status == 'Due'
                                        ? Colors.red
                                        : status == 'Due Soon'
                                            ? Colors.orange
                                            : Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
