import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_ventory_mobile/main.dart' as app;
import 'dart:math';
import 'package:my_ventory_mobile/Controller/myventory_search_bar.dart';

// Reuse helper functions from register_test.dart
String generateRandomUsername() {
  final random = Random();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  final randomString = List.generate(5, (index) => chars[random.nextInt(chars.length)]).join();
  return 'test_$randomString$timestamp';
}

class TestCredentials {
  final String username;
  final String password;
  TestCredentials(this.username, this.password);
}

Future<void> testRegistration(WidgetTester tester, TestCredentials creds) async {
  final registerButton = find.text('First time here? Create new account!');
  await tester.tap(registerButton);
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextField, 'Username'), creds.username);
  await tester.enterText(find.widgetWithText(TextField, 'First Name'), 'Test');
  await tester.enterText(find.widgetWithText(TextField, 'Last Name'), 'User');
  await tester.enterText(find.widgetWithText(TextField, 'Email'), '${creds.username}@test.com');
  await tester.enterText(find.widgetWithText(TextField, 'Password'), creds.password);

  await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
  await tester.pumpAndSettle(const Duration(seconds: 2));

  expect(find.text('User created successfully!'), findsOneWidget);
}

Future<void> testLogin(WidgetTester tester, TestCredentials creds) async {
  await tester.enterText(find.widgetWithText(TextField, 'Username or Email'), creds.username);
  await tester.enterText(find.widgetWithText(TextField, 'Password'), creds.password);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
  await tester.pumpAndSettle(const Duration(seconds: 4));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Lending Feature Tests', () {
    testWidgets('Complete lending flow test', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Create and login with test user
      final creds = TestCredentials(
        generateRandomUsername(),
        'TestPassword123!'
      );

      await testRegistration(tester, creds);
      await testLogin(tester, creds);

      // Create a test item first (since we need an item to lend)
      await tester.tap(find.byIcon(Icons.inventory_2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add new item'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Test Item');
      await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'Description'), 'Test Description');
      
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Navigate to Lendings page
      await tester.tap(find.byIcon(Icons.share));
      await tester.pumpAndSettle();

      // Verify Lendings page elements
      expect(find.text('Lendings'), findsOneWidget);
      expect(find.byType(MyventorySearchBar), findsOneWidget);
      
      // Test status filter
      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();
      
      expect(find.text('All'), findsOneWidget);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // Test creating new lending
      final createButtonFinder = find.text('Create a new lending');
      expect(createButtonFinder, findsOneWidget);
      await tester.tap(createButtonFinder);
      await tester.pumpAndSettle();

      // Fill in new lending form
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Borrower Name'),
        'Test Borrower'
      );
      await tester.pumpAndSettle();

      // Select due date
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      
      // Select a date from date picker
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Select the test item we created
      final addItemButton = find.byIcon(Icons.add).first;
      await tester.tap(addItemButton);
      await tester.pumpAndSettle();

      // Submit the lending
      final submitButton = find.text('Create Lending');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify the new lending appears in the list
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Test Borrower'), findsOneWidget);

      // Test ending a lending
      await tester.tap(find.text('Test Borrower'));
      await tester.pumpAndSettle();

      final endLendingButton = find.text('End Lending');
      expect(endLendingButton, findsOneWidget);
      await tester.tap(endLendingButton);
      await tester.pumpAndSettle();

      // Go back to lendings list
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Test status filter for Finished lendings
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finished'));
      await tester.pumpAndSettle();

      // Verify our ended lending appears in Finished status
      expect(find.text('Test Borrower'), findsOneWidget);
    });

    testWidgets('Borrowings view test', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Login with existing credentials
      final creds = TestCredentials(
        generateRandomUsername(),
        'TestPassword123!'
      );
      await testRegistration(tester, creds);
      await testLogin(tester, creds);

      // Navigate to Lendings page
      await tester.tap(find.byIcon(Icons.share));
      await tester.pumpAndSettle();

      // Switch to Borrowings view
      await tester.tap(find.text('Borrowings'));
      await tester.pumpAndSettle();

      // Verify borrowings view elements
      expect(find.text('Request a new borrowing'), findsOneWidget);
      
      // Test status filter in borrowings view
      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();
      
      // Verify all status options are available in borrowings view
      expect(find.text('All'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Due Soon'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
    });
  });
}
