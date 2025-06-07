import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';
import 'package:my_ventory_mobile/Model/visibility_button.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final TextEditingController userNameC = TextEditingController();
  final TextEditingController firstNameC = TextEditingController();
  final TextEditingController lastNameC = TextEditingController();
  final TextEditingController emailC = TextEditingController();
  final TextEditingController passwordC = TextEditingController();

  final GlobalKey<TextBoxState> passwordKey = GlobalKey<TextBoxState>();
  final _apiService = ApiService();

  Future<void> sendVerificationEmail() async {
    try {
      final response = await _apiService.post(
        '/users/resend-verification-email',
        {"email": emailC.text.trim()},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Error is already handled by the registration message
      }
    } catch (e) {
      // Error is already handled by the registration message
    }
  }

  Future<void> registerUser() async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      final response = await _apiService.post(
        '/users?verifyMailRequested=true',
        {
          'userName': userNameC.text,
          'firstName': firstNameC.text,
          'lastName': lastNameC.text,
          'email': emailC.text,
          'password': passwordC.text,
        },
        isMultipart: true,
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        // Send verification email
        await sendVerificationEmail();

        scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text(
              'Account created successfully! Please check your email to verify your account.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ));
        navigator.pop();
      } else {
        // Try to parse the error message from the response
        String errorMessage = 'Registration failed!';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['errors'] != null) {
            // Handle multiple validation errors
            final errors = errorData['errors'] as Map<String, dynamic>;
            errorMessage = errors.values.first.toString();
          }
        } catch (e) {
          // If parsing fails, use the default message
        }

        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 131, 184, 175),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 87, 143, 134),
        title: const Text('Register', style: TextStyle(color: Colors.white)),
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
              Center(
                child: TextBox(
                  backText: "Username",
                  boxC: userNameC,
                  boxWidth: screenWidth * 0.8,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextBox(
                  backText: "First Name",
                  boxC: firstNameC,
                  boxWidth: screenWidth * 0.8,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextBox(
                  backText: "Last Name",
                  boxC: lastNameC,
                  boxWidth: screenWidth * 0.8,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextBox(
                  backText: "Email",
                  boxC: emailC,
                  boxWidth: screenWidth * 0.8,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextBox(
                  key: passwordKey,
                  backText: "Password",
                  boxC: passwordC,
                  boxWidth: screenWidth * 0.8,
                  obscureTxtFt: true,
                  featureButton: VisibilityButton(
                    textBoxKey: passwordKey,
                    toggleObscure: () {
                      passwordKey.currentState?.toggleObscure();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 87, 143, 134),
                    foregroundColor: Colors.white,
                    minimumSize: Size(screenWidth * 0.4, 48),
                  ),
                  onPressed: registerUser,
                  child: const Text("Register"),
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
    userNameC.dispose();
    firstNameC.dispose();
    lastNameC.dispose();
    emailC.dispose();
    passwordC.dispose();
    super.dispose();
  }
}
