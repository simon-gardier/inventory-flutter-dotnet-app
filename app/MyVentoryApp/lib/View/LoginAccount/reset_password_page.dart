import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';
import 'dart:convert';

class ResetPasswordPage extends StatefulWidget {
  final String? email;

  const ResetPasswordPage({
    super.key,
    this.email,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool isResendingVerification = false;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }
  }

  Future<void> resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      final response = await _apiService.post(
        '/users/forgot-password',
        {"email": _emailController.text.trim()},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = {};
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          // If parsing fails, continue with default message
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ??
                'Password reset instructions sent to your email'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to login page after sending reset instructions
        navigator.pushReplacementNamed('/login');
      } else {
        // debugPrint('Failed response: ${response.statusCode} - ${response.body}');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Email not found or error occurred'),
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
        setState(() => _isLoading = false);
      }
    }
  }

  // Add new method for resending verification email
  Future<void> resendVerificationEmail() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    setState(() => isResendingVerification = true);

    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      final response = await _apiService.post(
        '/users/resend-verification-email',
        {"email": _emailController.text.trim()},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = {};
        try {
          responseData = jsonDecode(response.body);
        } catch (e) {
          // If parsing fails, continue with default message
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ??
                'Verification email has been resent'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // debugPrint('Failed response: ${response.statusCode} - ${response.body}');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Email not found or error occurred'),
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
        setState(() => isResendingVerification = false);
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
            const Text('Reset Password', style: TextStyle(color: Colors.white)),
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
                padding: EdgeInsets.all(5.0),
                child: Text(
                  'Enter your email address and we\'ll send you instructions to reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(0.0),
                child: Text(
                  'Or',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(5.0),
                child: Text(
                  'If you haven\'t verified your email yet, you can resend the verification email.',
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
                  boxC: _emailController,
                  boxWidth: screenWidth * 0.8,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: _isLoading
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
                        onPressed: resetPassword,
                        child: const Text("Send Reset Link"),
                      ),
              ),

              // Add Resend Verification Email button
              const SizedBox(height: 16),
              Center(
                child: isResendingVerification
                    ? const CircularProgressIndicator(
                        color: Color.fromARGB(255, 87, 143, 134),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor:
                              const Color.fromARGB(255, 87, 143, 134),
                          minimumSize: Size(screenWidth * 0.4, 48),
                          side: const BorderSide(
                            color: Color.fromARGB(255, 87, 143, 134),
                          ),
                        ),
                        onPressed: resendVerificationEmail,
                        child: const Text("Resend Verification Email"),
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
    _emailController.dispose();
    super.dispose();
  }
}
