import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_ventory_mobile/main.dart' as app;
import 'dart:math';

// Helper function to generate random username
String generateRandomUsername() {
  final random = Random();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  final randomString = List.generate(5, (index) => chars[random.nextInt(chars.length)]).join();
  return 'test_$randomString$timestamp';
}

// Test credentials class to share between functions
class TestCredentials {
  final String username;
  final String password;
  TestCredentials(this.username, this.password);
}

Future<void> testRegistration(WidgetTester tester, TestCredentials creds) async {
  // Navigate to registration page
  final registerButton = find.text('First time here? Create new account!');
  await tester.tap(registerButton);
  await tester.pumpAndSettle();

  // Fill in the registration form
  await tester.enterText(find.widgetWithText(TextField, 'Username'), creds.username);
  await tester.enterText(find.widgetWithText(TextField, 'First Name'), 'Test');
  await tester.enterText(find.widgetWithText(TextField, 'Last Name'), 'User');
  await tester.enterText(find.widgetWithText(TextField, 'Email'), '${creds.username}@test.com');
  await tester.enterText(find.widgetWithText(TextField, 'Password'), creds.password);

  // Submit the form
  await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
  await tester.pumpAndSettle(const Duration(seconds: 2));

  // Verify registration success
  expect(find.text('User created successfully!'), findsOneWidget);
  expect(find.byType(MaterialApp), findsOneWidget);
}

Future<void> testLogin(WidgetTester tester, TestCredentials creds) async {
  await tester.enterText(find.widgetWithText(TextField, 'Username or Email'), creds.username);
  await tester.enterText(find.widgetWithText(TextField, 'Password'), creds.password);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
  
  // Wait for the login process and navigation
  await tester.pumpAndSettle(const Duration(seconds: 4));  // Increased wait time

  // Verify successful login and navigation to inventory page
  //expect(find.text('Inventory'), findsOneWidget);  // Verify the page title
}

Future<void> testLogout(WidgetTester tester) async {
  // Navigate to Account page using the correct button structure
  final accountIcon = find.byIcon(Icons.account_circle);
  expect(accountIcon, findsOneWidget);
  await tester.tap(accountIcon);
  await tester.pumpAndSettle();

  // Find and tap the red Logout button
  final logoutButton = find.widgetWithText(ElevatedButton, 'Logout');
  expect(logoutButton, findsOneWidget);
  await tester.tap(logoutButton);
  await tester.pumpAndSettle();

  // Verify we're redirected to login page
  expect(find.text('First time here? Create new account!'), findsOneWidget);
}

Future<void> testDeleteAccount(WidgetTester tester) async {
  // Update the navigation here too
  final accountIcon = find.byIcon(Icons.account_circle);
  expect(accountIcon, findsOneWidget);
  await tester.tap(accountIcon);
  await tester.pumpAndSettle();
  
  // Rest of delete account test...
  await tester.tap(find.widgetWithText(ElevatedButton, 'Edit Profile'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Delete My Account'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> testInvalidLogin(WidgetTester tester, TestCredentials creds) async {
  await tester.enterText(find.widgetWithText(TextField, 'Username or Email'), creds.username);
  await tester.enterText(find.widgetWithText(TextField, 'Password'), creds.password);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text('Invalid credentials'), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('User Lifecycle Test', () {
    testWidgets('Complete user lifecycle: register, login, logout, delete', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Generate credentials that will be used throughout the test
      final creds = TestCredentials(
        generateRandomUsername(),
        'TestPassword123!'
      );
      // print('Testing with username: ${creds.username}');

      // Run test sequence
      // print('Running testRegistration');
      await testRegistration(tester, creds);
      // print('Running testLogin');
      await testLogin(tester, creds);
      // print('Running testLogout');
      await testLogout(tester);
      // print('Running testLogin');
      await testLogin(tester, creds);
      // print('Running testDeleteAccount');
      await testDeleteAccount(tester);
      // print('Running testInvalidLogin');
      await testInvalidLogin(tester, creds);
    });
  });
}