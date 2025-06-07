import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  DeleteAccountState createState() => DeleteAccountState();
}

class DeleteAccountState extends State<DeleteAccountPage> {
  bool isLoading = false;
  late int userId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userId = await AuthService.getUserId();
    if (userId != null) {
      setState(() {
        this.userId = userId;
      });
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => isLoading = true);

    try {
      final response = await ApiService().delete(
        '/users/$userId',
        context: context,
      );
      if (response.statusCode == 204) {
        await AuthService.logout();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
        }
      } else if (response.statusCode == 404) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Failed to delete account. Please try again later.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 131, 184, 175),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 87, 143, 134),
        title:
            const Text('Delete Account', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16.0),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                width: screenWidth * 0.8,
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Warning: Account Deletion',
                            style: TextStyle(
                              color: Colors.red[900],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This action will permanently delete your account and all associated data. This cannot be undone.',
                      style: TextStyle(color: Colors.red[900]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: isLoading
                    ? const CircularProgressIndicator(
                        color: Color.fromARGB(255, 87, 143, 134),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: Size(screenWidth * 0.4, 48),
                        ),
                        onPressed: _deleteAccount,
                        child: const Text("Delete My Account"),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
