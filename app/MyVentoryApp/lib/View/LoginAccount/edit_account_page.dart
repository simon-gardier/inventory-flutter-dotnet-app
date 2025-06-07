import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';
import 'package:my_ventory_mobile/Model/visibility_button.dart';
import 'package:my_ventory_mobile/API_authorizations/auth_service.dart';
import 'package:http_parser/http_parser.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart';
import 'package:my_ventory_mobile/API_authorizations/api_service.dart' as api_service;

class EditAccountPage extends StatefulWidget {
  const EditAccountPage({super.key});

  @override
  EditAccountPageState createState() => EditAccountPageState();
}

class EditAccountPageState extends State<EditAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<TextBoxState> passwordKey = GlobalKey<TextBoxState>();
  final TextEditingController _deletePasswordController = TextEditingController();
  
  // For image selection
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  String? _currentProfilePicture;
  bool _isLoading = false;
  late int _userId;
  // Instance for compatibility with saveAuthData
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await _authService.getUserData();
    if (userData != null) {
      setState(() {
        _userId = userData['userId'];
        _userNameController.text = userData['username'] ?? '';
        _firstNameController.text = userData['firstName'] ?? '';
        _lastNameController.text = userData['lastName'] ?? '';
        _emailController.text = userData['email'] ?? '';
        _currentProfilePicture = userData['profilePicture'];
      });
    }
  }

  void _updateDisplayedData(Map<String, dynamic> userData) {
    setState(() {
      _userNameController.text = userData['username'] ?? '';
      _firstNameController.text = userData['firstName'] ?? '';
      _lastNameController.text = userData['lastName'] ?? '';
      _emailController.text = userData['email'] ?? '';
      _currentProfilePicture = userData['profilePicture'];
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImage = pickedFile;
        _imageBytes = bytes;
        _currentProfilePicture = null; // Clear current profile picture
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please enter your current password to save changes')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      
      // First verify the current password using the new verify-password endpoint
      try {
        final verifyHeaders = {
          'Content-Type': 'application/json',
        };

        // Prepare request body
        final verifyBody = {
          'userId': int.parse(_userId.toString()),
          'password': _passwordController.text,
        };

        final verifyResponse = await api_service.ApiService().post(
          '/users/verify-password', 
          jsonEncode(verifyBody),
          customHeaders: verifyHeaders
        );

        // final verifyResponse = await http.post(
        //   Uri.parse('${AppConfig.apiBaseUrl}/users/verify-password'),
        //   headers: {
        //     'accept': '*/*',
        //     'Content-Type': 'application/json',
        //     'Authorization': 'Bearer $token',
        //   },
        //   body: jsonEncode(verifyBody),
        // );

        if (verifyResponse.statusCode != 200) {
          Map<String, dynamic> errorData;
          try {
            errorData = jsonDecode(verifyResponse.body);
          } catch (e) {
            throw Exception('Invalid password or authentication error');
          }
          
          String errorMessage = 'Invalid current password';
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          } else if (errorData['detail'] != null) {
            errorMessage = errorData['detail'];
          }
          throw Exception(errorMessage);
        }
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      Map<String, dynamic> userData = {};

      // Prépare les champs et fichiers pour le multipart
      final fields = {
        'userName': _userNameController.text,
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'email': _emailController.text,
      };
      final files = <http.MultipartFile>[];

      // Add image only if one was selected
      if (_selectedImage != null && _imageBytes != null) {
        files.add(http.MultipartFile.fromBytes(
          'image',
          _imageBytes!,
          filename: 'image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      } else if (_selectedImage != null) {
        files.add(await http.MultipartFile.fromPath(
          'image',
          _selectedImage!.path,
        ));
      }

      if (!mounted) return;
      final response = await ApiService().multipartPut(
        '/users/$_userId',
        fields,
        files,
        context: context,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        try {
          // If we got a 200 response with user data, update the userData with the response
          if (response.body.isNotEmpty) {
            Map<String, dynamic> responseData = jsonDecode(response.body);
            // Update userData with any returned data from the API
            responseData.forEach((key, value) {
              if (value != null) {
                userData[key] = value;
              }
            });

            _updateDisplayedData(userData);
          }
          
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Account updated successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Pop and return the updated data to the parent page
          navigator.pop(userData);
        } catch (e) {
          if (!mounted) return;
          String errorMessage = 'Failed to update account';
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        final token = await AuthService.getToken();

        // Make sure the token is preserved
        if (token != null && !userData.containsKey('token')) {
          userData['token'] = token;
        }

        // Save updated user data to AuthService
        await _authService.saveAuthData(userData);
        
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
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
    double screenWidth = MediaQuery.of(context).size.width;

    // Determine which image to display
    Widget profileImageWidget;

    if (_imageBytes != null) {
      // For selected image
      profileImageWidget = CircleAvatar(
        radius: 50,
        backgroundImage: MemoryImage(_imageBytes!),
      );
    } else if (_currentProfilePicture != null) {
      // For existing profile picture from the server
      try {
        profileImageWidget = CircleAvatar(
          radius: 50,
          backgroundImage: MemoryImage(base64Decode(_currentProfilePicture!)),
        );
      } catch (e) {
        // Fallback for decoding errors
        profileImageWidget = const CircleAvatar(
          radius: 50,
          backgroundImage: AssetImage('assets/default_profile.jpg'),
        );
      }
    } else {
      // Default profile picture
      profileImageWidget = const CircleAvatar(
        radius: 50,
        backgroundImage: AssetImage('assets/default_profile.jpg'),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 131, 184, 175),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 87, 143, 134),
        title:
            const Text('Edit Account', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      profileImageWidget,
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 87, 143, 134),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextBox(
                    backText: "Username",
                    boxC: _userNameController,
                    boxWidth: screenWidth * 0.8,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextBox(
                    backText: "First Name",
                    boxC: _firstNameController,
                    boxWidth: screenWidth * 0.8,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextBox(
                    backText: "Last Name",
                    boxC: _lastNameController,
                    boxWidth: screenWidth * 0.8,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextBox(
                    backText: "Email",
                    boxC: _emailController,
                    boxWidth: screenWidth * 0.8,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextBox(
                    key: passwordKey,
                    backText: "Current Password",
                    boxC: _passwordController,
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
                    onPressed: () {
                      Navigator.pushNamed(context, '/change-password',
                          arguments: {'userId': _userId});
                    },
                    child: const Text("Change Password"),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: Size(screenWidth * 0.4, 48),
                    ),
                    onPressed: _showDeletePasswordDialog,
                    child: const Text("Delete Account"),
                  ),
                ),
                const SizedBox(height: 16),
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
                          onPressed: _saveChanges,
                          child: const Text("Save Changes"),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPasswordForDelete() async {

    final verifyHeaders = {
      'Content-Type': 'application/json',
    };

    final verifyBody = {
      'userId': int.parse(_userId.toString()),
      'password': _deletePasswordController.text,
    };

    try {
      final verifyResponse = await api_service.ApiService().post(
        '/users/verify-password', 
        jsonEncode(verifyBody),
        customHeaders: verifyHeaders
      );

      // final verifyResponse = await http.post(
      //   Uri.parse('${AppConfig.apiBaseUrl}/users/verify-password'),
      //   headers: {
      //     'accept': '*/*',
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $token',
      //   },
      //   body: jsonEncode(verifyBody),
      // );

      if (!mounted) return;

      if (verifyResponse.statusCode == 200) {
        // Password verified, navigate to delete account page
        Navigator.pushNamed(
          context,
          '/delete-account',
          arguments: {'userId': _userId},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid password'),
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
    }
    _deletePasswordController.clear();
  }

  Future<void> _showDeletePasswordDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Password'),
        content: TextField(
          controller: _deletePasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Enter your current password',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _deletePasswordController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _verifyPasswordForDelete();
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }
}
