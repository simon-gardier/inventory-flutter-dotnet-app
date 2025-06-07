import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';
import 'dart:convert';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ChangePasswordState createState() => ChangePasswordState();
}

class ChangePasswordState extends State<ChangePasswordPage> {
  final TextEditingController emailC = TextEditingController();
  bool isLoading = false;
  final _apiService = ApiService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final userData = await _authService.getUserData();
    if (userData != null && userData['email'] != null) {
      setState(() {
        emailC.text = userData['email'];
      });
    }
  }

  Future<void> requestPasswordReset() async {
    if (emailC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Use the forgot-password API endpoint
      final response = await _apiService.post(
        '/users/forgot-password',
        jsonEncode({"email": emailC.text.trim()}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = {};
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          // If parsing fails, continue with default message
        }

        // Show success dialog instead of just a snackbar
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Password Reset Email Sent'),
              content: Text(responseData['message'] ??
                  'A password reset link has been sent to your email. Please check your inbox to complete the password reset process.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Return to previous screen
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        // More detailed error handling
        String errorMessage =
            'Failed to send password reset email. Please try again later.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // If parsing fails, use the default message
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
        title: const Text('Change Password',
            style: TextStyle(color: Colors.white)),
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
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'To change your password, we\'ll send a password reset link to your email address.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextBox(
                  backText: "Email",
                  boxC: emailC,
                  boxWidth: screenWidth * 0.8,
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
                          backgroundColor:
                              const Color.fromARGB(255, 87, 143, 134),
                          foregroundColor: Colors.white,
                          minimumSize: Size(screenWidth * 0.4, 48),
                        ),
                        onPressed: requestPasswordReset,
                        child: const Text("Send Reset Link"),
                      ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'You will receive an email with instructions on how to securely reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailC.dispose();
    super.dispose();
  }
}
