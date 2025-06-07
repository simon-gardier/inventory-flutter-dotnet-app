import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:my_ventory_mobile/Controller/user_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

import 'package:app_links/app_links.dart';

class LoginCallbackPage extends StatefulWidget {
  const LoginCallbackPage({super.key});

  @override
  State<LoginCallbackPage> createState() => _LoginCallbackPageState();
}

class _LoginCallbackPageState extends State<LoginCallbackPage> {
  bool _isLoading = true;
  String? _error;
  bool _shouldNavigate = false;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      Map<String, dynamic>? userData;
      String? token;
      String? refreshToken;

      if (kIsWeb) {
        final uri = Uri.base;
        if (uri.queryParameters['response'] != null) {
          final responseJson =
              Uri.decodeComponent(uri.queryParameters['response']!);
          final responseData = json.decode(responseJson);
          token = responseData['token'];
          userData = responseData['user'];
          refreshToken = responseData['refreshToken'];
        } else {
          final fragment = uri.fragment;
          if (fragment.isNotEmpty) {
            final fragmentUri =
                Uri.parse(fragment.startsWith('/') ? fragment : '/$fragment');
            if (fragmentUri.queryParameters['response'] != null) {
              final responseJson =
                  Uri.decodeComponent(fragmentUri.queryParameters['response']!);
              final responseData = json.decode(responseJson);
              token = responseData['token'];
              userData = responseData['user'];
              refreshToken = responseData['refreshToken'];
            } else if (fragmentUri.queryParameters['token'] != null) {
              token = fragmentUri.queryParameters['token'];
              userData = null;
            }
          }
        }
      } else {
        // Mobile: deep link
        final appLinks = AppLinks();
        final initialUri = await appLinks.getInitialLink();
        if (initialUri != null) {
          final uri = Uri.parse(initialUri.toString());
          if (uri.queryParameters['response'] != null) {
            final responseJson =
                Uri.decodeComponent(uri.queryParameters['response']!);
            final responseData = json.decode(responseJson);
            token = responseData['token'];
            userData = responseData['user'];
            refreshToken = responseData['refreshToken'];
          } else if (uri.queryParameters['token'] != null) {
            token = uri.queryParameters['token'];
            userData = null;
          }
        }
      }

      if (token != null &&
          token.isNotEmpty &&
          userData != null &&
          refreshToken != null &&
          refreshToken.isNotEmpty) {
        var email = userData['Email'];

        final result = await UserController.loginUserSsoAndSaveData(
          email: email,
          token: token,
          refreshToken: refreshToken,
        );

        if (!mounted || !result) return;
        setState(() {
          _shouldNavigate = true;
          _isLoading = false;
          _error = null;
        });
        return;
      }

      setState(() {
        _error = "No valid user data or token found in callback URL.";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error during login callback: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldNavigate && !_isLoading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (kIsWeb) {
            html.window.history.replaceState(null, '', '/#/inventory');
          }
          Navigator.of(context).pushReplacementNamed('/inventory');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: Center(child: Text(_error ?? "Unknown error")),
    );
  }
}
