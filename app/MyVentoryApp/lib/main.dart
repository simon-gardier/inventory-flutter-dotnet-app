import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:my_ventory_mobile/View/LoginAccount/verify_account_page.dart';
import 'dart:async';
import 'dart:io';

// MainPages imports
import 'package:my_ventory_mobile/View/MainPages/inventory_page.dart';
import 'package:my_ventory_mobile/View/MainPages/lendings_page.dart';
import 'package:my_ventory_mobile/View/MainPages/add_item_page.dart';
import 'package:my_ventory_mobile/View/MainPages/groups_page.dart';

// LoginAccount imports
import 'package:my_ventory_mobile/View/LoginAccount/login_page.dart';
import 'package:my_ventory_mobile/View/LoginAccount/register_page.dart';
import 'package:my_ventory_mobile/View/LoginAccount/account_page.dart';
import 'package:my_ventory_mobile/View/LoginAccount/edit_account_page.dart';
import 'package:my_ventory_mobile/View/LoginAccount/reset_password_page.dart';
import 'package:my_ventory_mobile/View/LoginAccount/change_password_page.dart';
import 'package:my_ventory_mobile/View/LoginAccount/delete_account_page.dart';
import 'package:my_ventory_mobile/View/LoginAccount/login_callback_page.dart';

// Other views
import 'package:my_ventory_mobile/View/reset_password_confirm_page.dart';

// HTTP security override class for development
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  // Setup HTTP security override for development
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Run the app without passing any navigator key
  runApp(const MyVentory());
}

class MyVentory extends StatefulWidget {
  const MyVentory({super.key});

  @override
  State<MyVentory> createState() => _MyVentoryState();
}

class _MyVentoryState extends State<MyVentory> {
  late AppLinks _appLinks;
  String? _deepLinkEmail;
  String? _deepLinkToken;
  final bool _isVerificationLink = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  // Handle deep links
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    // Handle initial link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _processDeepLink(initialUri.toString());
      }
    } catch (e) {
      // Do nothing
    }

    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _processDeepLink(uri.toString());
      }
    }, onError: (e) {
      // Do nothing
    });
  }

  // Process deep link and extract parameters
  void _processDeepLink(String link) {
    try {
      final uri = Uri.parse(link);
      if (link.contains('login/callback')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/login/callback');
        });
        return;
      }

      if (link.contains('reset-password')) {
        String? email;
        String? token;

        // Check query parameters first
        email = uri.queryParameters['email'];
        token = uri.queryParameters['token'];

        // Check fragment if needed
        if (email == null || token == null) {
          final fragmentString = uri.fragment;
          if (fragmentString.isNotEmpty) {
            try {
              // Check if the fragment starts with a slash and contains a query
              if (fragmentString.startsWith('/')) {
                final fragmentUri =
                    Uri.parse('http://dummy.com$fragmentString');
                email = email ?? fragmentUri.queryParameters['email'];
                token = token ?? fragmentUri.queryParameters['token'];
              } else if (fragmentString.contains('?')) {
                // Handle fragments like #reset-password?token=xyz
                final parts = fragmentString.split('?');
                if (parts.length > 1) {
                  final queryString = parts[1];
                  final queryParams = Uri.splitQueryString(queryString);
                  email = email ?? queryParams['email'];
                  token = token ?? queryParams['token'];
                }
              }
            } catch (e) {
              // Do nothing
            }
          }
        }

        if (email != null && token != null) {
          final decodedEmail = Uri.decodeComponent(email);
          String decodedToken = token;

          if (token.contains('%')) {
            try {
              decodedToken =
                  Uri.decodeComponent(token.replaceAll('+', '__PLUS__'))
                      .replaceAll('__PLUS__', '+');
            } catch (e) {
              decodedToken = token;
            }
          }

          setState(() {
            _deepLinkEmail = decodedEmail;
            _deepLinkToken = decodedToken;
          });
        }
      }
    } catch (e) {
      // Do nothing
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we need to show a specific page from a deep link
    Widget? initialPage;
    if (_deepLinkEmail != null && _deepLinkToken != null) {
      if (_isVerificationLink) {
        initialPage = VerifyAccountPage(
          email: _deepLinkEmail!,
          token: _deepLinkToken!,
        );
      } else {
        initialPage = ResetPasswordConfirmPage(
          email: _deepLinkEmail!,
          token: _deepLinkToken!,
        );
      }
    }

    return MaterialApp(
      title: 'MyVentory',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade200),
        useMaterial3: true,
      ),
      home: initialPage ?? const LoginPage(),
      initialRoute: initialPage != null ? null : '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/inventory': (context) => InventoryPage(),
        '/groups': (context) => GroupsPage(),
        '/add': (context) => AddItemPage(),
        '/lendings': (context) => LendingsPage(),
        '/account': (context) => AccountPage(),
        '/register': (context) => const RegisterPage(),
        '/editAccount': (context) => EditAccountPage(),
        '/verify-account': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, String>?;
          return VerifyAccountPage(
            email: args?['email'] ?? '',
            token: args?['token'] ?? '',
          );
        },
        '/reset-password': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, String>?;
          return ResetPasswordPage(
            email: args?['email'],
          );
        },
        '/change-password': (context) => const ChangePasswordPage(),
        '/delete-account': (context) => const DeleteAccountPage(),
        '/login/callback': (context) => const LoginCallbackPage(),
        // Add the route for reset password confirmation with proper type safety
        '/reset-password-confirm': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;

          // Safely handle arguments of different types
          if (args is Map<String, dynamic>) {
            final email = args['email'] as String? ?? '';
            final token = args['token'] as String? ?? '';
            return ResetPasswordConfirmPage(email: email, token: token);
          }

          // Fallback if arguments are missing or invalid
          return const LoginPage();
        },
      },
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        if (uri.path == '/login/callback') {
          return MaterialPageRoute(
            builder: (context) => const LoginCallbackPage(),
            settings: settings,
          );
        }
        return null; // Return null for unhandled routes
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
