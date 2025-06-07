import 'package:flutter/material.dart';
import 'package:my_ventory_mobile/Model/clear_text_button.dart';
import 'package:my_ventory_mobile/Model/text_boxes.dart';
import 'package:my_ventory_mobile/Model/visibility_button.dart';
import 'package:my_ventory_mobile/Controller/user_controller.dart';
import 'package:my_ventory_mobile/Config/config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:universal_html/html.dart' as uni_html;
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController usrC = TextEditingController();
  final TextEditingController pswrdC = TextEditingController();
  final GlobalKey<TextBoxState> usrKey = GlobalKey<TextBoxState>();
  final GlobalKey<TextBoxState> pswrdKey = GlobalKey<TextBoxState>();
  late VisibilityButton vb;
  late ClearTextButton ctb;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    vb = VisibilityButton(
      textBoxKey: pswrdKey,
      toggleObscure: () => pswrdKey.currentState?.toggleObscure(),
    );
    ctb = ClearTextButton(textBoxKey: usrKey, boxC: usrC);
  }

  void recoverPswrd() {
    Navigator.pushNamed(context, '/reset-password');
  }

  void createAccount() {
    Navigator.pushNamed(context, '/register');
  }

  Future<void> login() async {
    final String usernameOrEmail = usrC.text.trim();
    final String password = pswrdC.text.trim();

    if (usernameOrEmail.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await UserController.loginUserAndSaveData(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );

      if (result) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/inventory');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() => isLoading = true);

    try {
      String provider;
      if (kIsWeb) {
        provider = 'GoogleWeb';
      } else if (Platform.isAndroid) {
        provider = 'GoogleAndroid';
      } else {
        provider = 'GoogleWeb';
      }

      final ssoUrl =
          '${AppConfig.apiBaseUrl}/auth/login/google?provider=$provider&returnUrl=${Uri.encodeComponent(AppConfig.apiBaseUrl)}';

      if (kIsWeb) {
        uni_html.window.location.assign(ssoUrl);
        return;
      } else {
        if (await canLaunchUrl(Uri.parse(ssoUrl))) {
          await launchUrl(Uri.parse(ssoUrl),
              mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $ssoUrl';
        }
      }

      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 131, 184, 175),
      body: Align(
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/login_logo.png'),
              const SizedBox(height: 30),
              TextBox(
                key: usrKey,
                backText: 'Username or Email',
                featureButton: ctb,
                boxC: usrC,
                boxWidth: 250,
              ),
              const SizedBox(height: 10),
              TextBox(
                key: pswrdKey,
                backText: 'Password',
                featureButton: vb,
                obscureTxtFt: true,
                boxC: pswrdC,
                boxWidth: 250,
              ),
              const SizedBox(height: 10),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                            const Color.fromARGB(255, 87, 143, 134)),
                        fixedSize: WidgetStatePropertyAll(const Size(250, 30)),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      onPressed: login,
                      child: const Text('Log In',
                          style: TextStyle(color: Colors.white)),
                    ),
              ElevatedButton(
                style: ButtonStyle(
                  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                  backgroundColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                  foregroundColor: const WidgetStatePropertyAll(
                      Color.fromARGB(255, 87, 143, 134)),
                ),
                onPressed: recoverPswrd,
                child: const Text('Forgot Password?'),
              ),
              const SizedBox(height: 10),
              Container(
                width: 250,
                height: 2,
                color: Colors.white,
              ),
              const SizedBox(height: 15),
              if (kIsWeb)
                ElevatedButton.icon(
                  icon: Image.asset(
                    'assets/Google_logo.png',
                    height: 20.0,
                    width: 20.0,
                  ),
                  label: const Text(
                    'Log In with Google',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black54,
                    fixedSize: const Size(250, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: signInWithGoogle,
                ),
              if (kIsWeb)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: const WidgetStatePropertyAll(
                      Color.fromARGB(255, 75, 222, 131)),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  fixedSize: WidgetStatePropertyAll(
                      const Size(250, 30)), // Set width to 250, height to 40
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8), // Set border radius to 8
                    ),
                  ),
                ),
                onPressed: createAccount,
                child: const Text('Create new account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
