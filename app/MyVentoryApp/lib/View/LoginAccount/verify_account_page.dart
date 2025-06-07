import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_ventory_mobile/Config/config.dart';

class VerifyAccountPage extends StatefulWidget {
  final String token;
  final String email;

  const VerifyAccountPage({
    super.key,
    required this.token,
    required this.email,
  });

  @override
  State<VerifyAccountPage> createState() => _VerifyAccountPageState();
}

class _VerifyAccountPageState extends State<VerifyAccountPage> {
  bool _isLoading = false;
  bool _isVerified = false;

  Future<void> _verifyAccount() async {
    setState(() => _isLoading = true);

    try {
      // Build URL with query parameters
      final Uri uri =
          Uri.parse('${AppConfig.apiBaseUrl}/users/verify-email').replace(
        queryParameters: {
          'token': widget.token,
          'email': widget.email,
        },
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _isVerified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Wait a moment before navigating to login
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        });
      } else {
        // Parse error message from response
        String errorMessage = 'Failed to verify account';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['detail'] != null) {
            errorMessage = errorData['detail'];
          }
        } catch (_) {
          // Use default error message if parsing fails
        }

        ScaffoldMessenger.of(context).showSnackBar(
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 131, 184, 175),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 87, 143, 134),
        title: const Text(
          'Verify Account',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Click the button below to verify your account',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator(
                  color: Color.fromARGB(255, 87, 143, 134),
                )
              else if (!_isVerified)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 87, 143, 134),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                  ),
                  onPressed: _verifyAccount,
                  child: const Text('Verify Account'),
                )
              else
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 64,
                ),
              if (_isVerified)
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: Text(
                    'Redirecting to login...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
