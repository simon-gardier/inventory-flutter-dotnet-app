import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/lending.dart' as lending_model;
import 'package:my_ventory_mobile/Model/page_template.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';

class LendingRecordPage extends PageTemplate {
  final lending_model.Lending lending;

  const LendingRecordPage({
    super.key,
    required this.lending,
  });

  @override
  PageTemplateState<LendingRecordPage> createState() =>
      LendingRecordPageState();
}

class LendingRecordPageState extends PageTemplateState<LendingRecordPage> {
  bool _isOwner = false;
  late lending_model.Lending _lending;
  int? userId;
  final _apiService = ApiService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _lending = widget.lending;
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userData = await _authService.getUserData();
    if (userData != null) {
      setState(() {
        userId = userData['userId'];
        _isOwner = userId == _lending.lenderId;
      });
    }
  }

  @override
  Widget pageBody(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              // Back button
              IconButton(
                padding: const EdgeInsets.all(16.0),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              // Title
              const Expanded(
                child: Text(
                  "Lending Details",
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
                  // Borrower informations
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Borrower',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text('Name: ${_lending.borrowerName}'),
                          if (_lending.borrowerId != null)
                            Text('ID: ${_lending.borrowerId}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dates information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dates',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Lending Date: ${_lending.lendingDate.toString().split(' ')[0]}'),
                          Text(
                              'Due Date: ${_lending.dueDate.toString().split(' ')[0]}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lent Items',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (_lending.lendItems != null)
                            ..._lending.lendItems!.map((item) => ListTile(
                                  title: Text(item.item.name),
                                  subtitle: Text('Quantity: ${item.quantity}'),
                                  leading: const Icon(Icons.inventory),
                                ))
                          else
                            const Text('No items found'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // End Lending button (only shown to owner and if not finished)
                  if (_isOwner && !(_lending.isFinished ?? false))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48.0,
                        child: ElevatedButton(
                          onPressed: () => _showEndLendingDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('End Lending'),
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

  void _showEndLendingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Lending'),
          content: const Text('Are you sure you want to end this lending?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _endLending();
                Navigator.of(context).pop();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _endLending() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final response = await _apiService.put(
          '/lendings/${widget.lending.transactionId}/end', '');

      if (!mounted) return;

      if (response.statusCode == 200) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Lending ended successfully')),
        );
        navigator.pop();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Failed to end lending: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
