import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:my_ventory_mobile/Model/text_boxes.dart';
import 'package:my_ventory_mobile/Model/page_template.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';

class ResetPasswordConfirmPage extends PageTemplate {
  final String email;
  final String token;

  const ResetPasswordConfirmPage({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  PageTemplateState<ResetPasswordConfirmPage> createState() =>
      ResetPasswordConfirmPageState();
}

class ResetPasswordConfirmPageState
    extends PageTemplateState<ResetPasswordConfirmPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  // Use ValueKey instead of GlobalKey to avoid conflicts
  // We'll manually handle the password visibility toggle
  final Key passwordKey = ValueKey('passwordKey_reset');
  final Key confirmPasswordKey = ValueKey('confirmPasswordKey_reset');
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  final _apiService = ApiService();
  String? _passwordError;
  String? _confirmPasswordError;
  String? _tokenError;

  @override
  void initState() {
    super.initState();

    // Fix token by converting spaces back to + signs
    final fixedToken = _fixTokenSpaces(widget.token);

    // Set the token from the widget parameter
    _tokenController.text = fixedToken;
  }

  // Convert spaces back to + in token (needed for URL-based tokens)
  String _fixTokenSpaces(String token) {
    return token.replaceAll(' ', '+');
  }

  // Clean token of potential encoding issues while preserving + signs
  String _cleanToken(String token) {
    if (token.isEmpty) return token;

    String cleanedToken = token.trim();

    // Decode percent-encoded characters while preserving + signs
    if (cleanedToken.contains('%')) {
      try {
        cleanedToken =
            Uri.decodeComponent(cleanedToken.replaceAll('+', '__PLUS__'))
                .replaceAll('__PLUS__', '+');
      } catch (e) {
        // If decoding fails, keep the original cleaned token
      }
    }

    return cleanedToken;
  }

  void _validateInputs() {
    setState(() {
      // Skip token validation if it came from deep link
      if (widget.token.isEmpty && _tokenController.text.isEmpty) {
        _tokenError = 'Please enter the token from your email';
      } else {
        _tokenError = null;
      }

      if (_newPasswordController.text.isEmpty) {
        _passwordError = 'Please enter a password';
      } else if (_newPasswordController.text.length < 8) {
        _passwordError = 'Password must be at least 8 characters';
      } else {
        _passwordError = null;
      }

      if (_confirmPasswordController.text.isEmpty) {
        _confirmPasswordError = 'Please confirm your password';
      } else if (_confirmPasswordController.text !=
          _newPasswordController.text) {
        _confirmPasswordError = 'Passwords do not match';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  bool _isFormValid() {
    _validateInputs();
    return _passwordError == null &&
        _confirmPasswordError == null &&
        _tokenError == null;
  }

  Future<void> _resetPassword() async {
    if (!_isFormValid()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = widget.email.trim();
      // Process the token to ensure + signs are preserved
      final token = _cleanToken(_fixTokenSpaces(widget.token).trim());

      // Prepare the API payload
      final payload = jsonEncode({
        "email": email,
        "token": token,
        "newPassword": _newPasswordController.text,
      });

      // Make the API request to reset password
      final response = await _apiService.post(
        '/users/reset-password',
        payload,
        skipAuth: true, // Skip auth token for password reset
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successful!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to login page
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        if (!mounted) return;

        // Show error message
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['message'] ?? 'Failed to reset password';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Do nothing
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
  Widget pageBody(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'Enter your new password below',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            // Show email for confirmation
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Email: ${widget.email}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Only show token field if it wasn't provided via deep link
            if (widget.token.isEmpty)
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextBox(
                      backText: "Reset Token",
                      boxC: _tokenController,
                      boxWidth: screenWidth * 0.8,
                    ),
                    if (_tokenError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, top: 5.0),
                        child: Text(
                          _tokenError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextBox(
                    key: passwordKey,
                    backText: "New Password",
                    boxC: _newPasswordController,
                    boxWidth: screenWidth * 0.8,
                    obscureTxtFt: _obscurePassword,
                    featureButton: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  if (_passwordError != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, top: 5.0),
                      child: Text(
                        _passwordError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextBox(
                    key: confirmPasswordKey,
                    backText: "Confirm Password",
                    boxC: _confirmPasswordController,
                    boxWidth: screenWidth * 0.8,
                    obscureTxtFt: _obscureConfirmPassword,
                    featureButton: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  if (_confirmPasswordError != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, top: 5.0),
                      child: Text(
                        _confirmPasswordError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
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
                      onPressed: () {
                        // Validate on button press
                        if (_isFormValid()) {
                          _resetPassword();
                        }
                      },
                      child: const Text("Reset Password"),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }
}
