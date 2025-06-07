import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  AccountPageState createState() => AccountPageState();
}

class AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool showMockWarning = false;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Use the instance method to get user data from AuthService
    final savedData = await _authService.getUserData();

    if (savedData != null) {
      setState(() {
        userData = savedData;
        isLoading = false;
      });

      // Refresh data from API in the background
      _refreshUserDataFromApi();
    } else {
      _fetchFromApi();
    }
  }

  Future<void> _refreshUserDataFromApi() async {
    try {
      final userId = await AuthService.getUserId();
      if (userId == null) return;

      final token = await AuthService.getToken();
      if (token == null) return;

      final response = await ApiService().get('/users/$userId');

      if (response.statusCode == 200) {
        final parsed = json.decode(response.body);

        // Preserve the token when saving the data
        parsed['token'] = token;

        // Save the updated user data to AuthService
        await _authService.saveAuthData(parsed);

        if (mounted) {
          setState(() {
            userData = parsed;
            showMockWarning = false;
          });
        }
      }
    } catch (e) {
      // Silently fail on background refresh
    }
  }

  Future<void> _fetchFromApi() async {
    try {
      final userId = await AuthService.getUserId();
      final token = await AuthService.getToken();

      if (userId == null || token == null) {
        _loadMockData();
        return;
      }

      final response = await ApiService().get('/users/$userId');

      if (response.statusCode == 200) {
        final parsed = json.decode(response.body);

        // Preserve the token when saving the data
        parsed['token'] = token;

        // Save the updated user data to AuthService
        await _authService.saveAuthData(parsed);

        setState(() {
          userData = parsed;
          isLoading = false;
          showMockWarning = false;
        });
      } else {
        // Don't clear existing data if we have it
        final existingData = await _authService.getUserData();
        if (existingData != null) {
          setState(() {
            userData = existingData;
            isLoading = false;
            showMockWarning = false;
          });
        } else {
          _loadMockData();
        }
      }
    } catch (e) {
      // Don't clear existing data if we have it
      final existingData = await _authService.getUserData();
      if (existingData != null) {
        setState(() {
          userData = existingData;
          isLoading = false;
          showMockWarning = false;
        });
      } else {
        _loadMockData();
      }
    }
  }

  void _loadMockData() {
    setState(() {
      userData = {
        'username': 'Demo User',
        'firstName': 'John',
        'lastName': 'Doe',
        'email': 'john.doe@example.com',
      };
      isLoading = false;
      showMockWarning = true;
    });
  }

  Widget _buildInfoRow(String label, String? value) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color.fromARGB(255, 87, 143, 134),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 87, 143, 134),
            ),
          ),
          Text(
            value ?? 'Not available',
            style: const TextStyle(
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
        backgroundColor: const Color.fromARGB(255, 131, 184, 175),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                color: Color.fromARGB(255, 87, 143, 134),
              ))
            : Stack(children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                  padding: const EdgeInsets.only(top: 16.0, left: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                    Navigator.pop(context);
                    },
                  ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (showMockWarning)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 16.0),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 20),
                            width: screenWidth * 0.8,
                            decoration: BoxDecoration(
                              color: Colors.amber[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.orange),
                                const SizedBox(width: 10),
                                Text(
                                  'Demo data - API unavailable',
                                  style: TextStyle(color: Colors.orange[800]),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: userData?['profilePicture'] != null
                              ? MemoryImage(
                                  base64Decode(userData!['profilePicture']))
                              : const AssetImage('assets/default_profile.jpg')
                                  as ImageProvider,
                        ),
                        const SizedBox(height: 24),
                        _buildInfoRow('Username', userData?['username']),
                        const SizedBox(height: 16),
                        _buildInfoRow('First Name', userData?['firstName']),
                        const SizedBox(height: 16),
                        _buildInfoRow('Last Name', userData?['lastName']),
                        const SizedBox(height: 16),
                        _buildInfoRow('Email', userData?['email']),
                        const SizedBox(height: 24),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 87, 143, 134),
                              foregroundColor: Colors.white,
                              minimumSize: Size(screenWidth * 0.4, 48),
                            ),
                            onPressed: () async {
                              final updatedData = await Navigator.pushNamed(
                                context,
                                '/editAccount',
                                arguments: {
                                  'userId': userData!['userId'],
                                  'userName': userData!['username'],
                                  'firstName': userData!['firstName'],
                                  'lastName': userData!['lastName'],
                                  'email': userData!['email'],
                                },
                              );

                              if (updatedData != null && mounted) {
                                setState(() {
                                  userData =
                                      updatedData as Map<String, dynamic>;
                                });
                              }
                            },
                            child: const Text('Edit Account'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              foregroundColor: Colors.white,
                              minimumSize: Size(screenWidth * 0.4, 48),
                            ),
                            onPressed: () => _handleLogout(context),
                            child: const Text('Logout'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]));
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Store navigator state before async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Use the static logout method from the updated AuthService
      await AuthService.logout();

      if (!mounted) return;

      navigator.pushReplacementNamed('/login');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error during logout: ${e.toString()}')),
      );
    }
  }
}
