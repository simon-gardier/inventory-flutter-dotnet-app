import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_ventory_mobile/main.dart' as app;
import 'package:my_ventory_mobile/Controller/vertical_elements_list.dart';
import 'package:my_ventory_mobile/Controller/single_choice_segmented_button.dart';
import 'package:my_ventory_mobile/View/Locations/location_folder_view.dart';
import 'package:my_ventory_mobile/View/Locations/location_directory_view.dart';
import 'package:my_ventory_mobile/Controller/filters_list.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Location Integration Tests', () {
    
    /// Login and wait for inventory page to load
    Future<void> loginToInventory(WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      // Find username/email field
      final emailField = find.byType(TextField).first;
      await tester.enterText(emailField, 'alexander');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      // Find password field
      final passwordField = find.byType(TextField).last;
      await tester.enterText(passwordField, 'Alexander123!');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      // Tap login button
      final loginButton = find.text('Login');
      await tester.tap(loginButton);
      
      // Wait for login to complete
      await tester.pumpAndSettle(const Duration(seconds: 4));
      
      expect(find.byType(VerticalElementsList), findsOneWidget);
    }
    
    // =====================================================================
    // TEST 1: Create a new sublocation
    // =====================================================================
    testWidgets('Create location test', (WidgetTester tester) async {
      // Login and get to inventory page
      await loginToInventory(tester);
      
      // Finds and click on the "Locations" segmented button
      
      final locationsSegment = find.descendant(
        of: find.byType(SingleChoiceSegmentedButton),
        matching: find.text('Locations'),
      );
      
      expect(locationsSegment, findsOneWidget, reason: 'Locations tab not found');
      
      await tester.tap(locationsSegment);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Verifies that we're in the Locations view
      expect(find.byType(LocationDirectoryView), findsOneWidget, reason: 'Location directory view not shown');
      
      // Finds folders in the Locations view
      final folderView = find.byType(LocationFolderView);
      expect(folderView, findsOneWidget, reason: 'Location folder view not found');
      
      // Finds the locations header
      final locationsHeader = find.text('Locations');
      expect(locationsHeader, findsWidgets, reason: 'Locations header not found');
      
      // Waits a moment for everything to load properly
      await tester.pump(const Duration(seconds: 1));
      
      // Find the expand/collapse icon near the Locations text
      final expandIcon = find.descendant(
        of: find.ancestor(
          of: locationsHeader.first,
          matching: find.byType(InkWell),
        ),
        matching: find.byType(Icon),
      );
      
      // Ensures folders are expanded (click on header if needed)
      if (tester.any(expandIcon) && 
          (tester.widget(expandIcon) as Icon).icon == Icons.expand_more) {
        await tester.tap(find.ancestor(
          of: locationsHeader.first,
          matching: find.byType(InkWell),
        ).first);
        await tester.pumpAndSettle();
      }
      
      // Finds any folder to click on
      final folderItems = find.descendant(
        of: folderView,
        matching: find.byType(InkWell),
      );
      
      // Verifies folders exist
      expect(folderItems, findsWidgets, reason: 'No folder items found');
      
      // Clicks on the first folder
      await tester.tap(folderItems.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Finds the "Add" button (contains add_circle_outline icon)
      final addButtons = find.byIcon(Icons.add_circle_outline);
      expect(addButtons, findsWidgets, reason: 'Add location button not found');
      
      // Taps the add button
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();
      
      // Verifies the dialog appears
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'Create location dialog not shown');
      expect(find.text('Create New Sublocation'), findsOneWidget, reason: 'Create sublocation title not found');
      
      // New location details
      final newLocationName = 'Test L-${DateTime.now().millisecondsSinceEpoch % 10000}';
      final newLocationCapacity = '100';
      final newLocationDescription = 'This is a test location created by integration test';
      
      // Fill in the form fields
      final nameField = find.widgetWithText(TextField, 'Name');
      await tester.enterText(nameField, newLocationName);
      await tester.pumpAndSettle();
      
      final capacityField = find.widgetWithText(TextField, 'Capacity');
      await tester.enterText(capacityField, newLocationCapacity);
      await tester.pumpAndSettle();
      
      final descriptionField = find.widgetWithText(TextField, 'Description');
      await tester.enterText(descriptionField, newLocationDescription);
      await tester.pumpAndSettle();
      
      // Tap the Create button
      final createButton = find.widgetWithText(TextButton, 'Create');
      await tester.tap(createButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // Wait for the location to be created and displayed
      // The SnackBar might not always be visible, skip checking for it
      // Instead use a more generous wait and look for the newly added location folder
      await tester.pumpAndSettle();
      
      // First ensure the folder view is refreshed and locations are shown
      // Explicitly wait to allow time for network call to complete
      await tester.pump(const Duration(seconds: 3));
      
      // Ensure folders are expanded - check again since UI might have reset
      if (tester.any(find.byIcon(Icons.expand_more))) {
        await tester.tap(find.ancestor(
          of: find.byIcon(Icons.expand_more).first,
          matching: find.byType(InkWell),
        ).first);
        await tester.pumpAndSettle();
      }
      
      // Find all visible location names to search for our new location
      bool foundNewLocation = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        // Get all text widgets in the folder view
        final allTexts = find.descendant(
          of: find.byType(LocationFolderView),
          matching: find.byType(Text),
        );
        
        // Check each text widget for our location name
        for (int i = 0; i < tester.widgetList(allTexts).length; i++) {
          final textWidget = tester.widget(allTexts.at(i)) as Text;
          if (textWidget.data != null && textWidget.data!.contains(newLocationName)) {
            foundNewLocation = true;
            
            // Find the parent InkWell that we need to tap to open the location
            final parentInkWell = find.ancestor(
              of: allTexts.at(i),
              matching: find.byType(InkWell),
            );
            
            if (tester.any(parentInkWell)) {
              await tester.tap(parentInkWell.first);
              await tester.pumpAndSettle(const Duration(seconds: 2));
              break;
            }
          }
        }
        
        if (foundNewLocation) break;
        
        // If not found, wait and refresh
        await tester.pump(const Duration(seconds: 1));
      }
      
      expect(foundNewLocation, true, reason: 'New location not found in folder view');
      
      // Verify we've navigated to the sublocation by looking for its name in the header
      final pathText = find.textContaining(newLocationName);
      expect(pathText, findsWidgets, reason: 'New location not shown in navigation path');
      
      // Verify we are in the correct location by checking for the location name
      final locationNameText = find.textContaining(newLocationName);
      expect(locationNameText, findsWidgets, reason: 'New location name not visible in the view');
    });
    // =====================================================================
    // TEST 2: Select date filters inside the location page
    // =====================================================================
    testWidgets('Location filter test', (WidgetTester tester) async {
      // Login and get to inventory page
      await loginToInventory(tester);
      
      // Find and click on the "Locations" segmented button
      final locationsSegment = find.descendant(
        of: find.byType(SingleChoiceSegmentedButton),
        matching: find.text('Locations'),
      );
      
      expect(locationsSegment, findsOneWidget, reason: 'Locations tab not found');
      
      await tester.tap(locationsSegment);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Verify that we're in the Locations view
      expect(find.byType(LocationDirectoryView), findsOneWidget, reason: 'Location directory view not shown');
      
      // Find folders in the Locations view
      final folderView = find.byType(LocationFolderView);
      expect(folderView, findsOneWidget, reason: 'Location folder view not found');
      
      // Find the locations header
      final locationsHeader = find.text('Locations');
      expect(locationsHeader, findsWidgets, reason: 'Locations header not found');
      
      // Wait a moment for everything to load properly
      await tester.pump(const Duration(seconds: 1));
      
      // Find the expand/collapse icon near the Locations text
      final expandIcon = find.descendant(
        of: find.ancestor(
          of: locationsHeader.first,
          matching: find.byType(InkWell),
        ),
        matching: find.byType(Icon),
      );
      
      // Ensure folders are expanded (click on header if needed)
      if (tester.any(expandIcon) && 
          (tester.widget(expandIcon) as Icon).icon == Icons.expand_more) {
        await tester.tap(find.ancestor(
          of: locationsHeader.first,
          matching: find.byType(InkWell),
        ).first);
        await tester.pumpAndSettle();
      }
      
      // Find any folder to click on
      final folderItems = find.descendant(
        of: folderView,
        matching: find.byType(InkWell),
      );
      
      // Verify folders exist
      expect(folderItems, findsWidgets, reason: 'No folder items found');
      
      // Get all folders and click on a random one (not necessarily the first)
      final int folderCount = tester.widgetList(folderItems).length;
      final int folderIndex = folderCount > 1 ? 1 : 0; // Choose second folder if available
      
      await tester.tap(folderItems.at(folderIndex));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Find the "Add filter" button
      final addFilterButton = find.text('Add filter');
      expect(addFilterButton, findsOneWidget, reason: 'Add filter button not found');
      
      // Tap the Add filter button
      await tester.tap(addFilterButton);
      await tester.pumpAndSettle();
      
      // Verify filter dialog appears
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'Filter selection dialog not shown');
      expect(find.text('Select Filter'), findsOneWidget, reason: 'Filter dialog title not found');
      
      // Find and tap on "Created After" date filter
      final createdAfterOption = find.descendant(
        of: find.byType(AlertDialog), 
        matching: find.text('Created After')
      );
      
      // If "Created After" is available, tap it, otherwise try "Created Before"
      if (tester.any(createdAfterOption)) {
        await tester.tap(createdAfterOption);
        await tester.pumpAndSettle();
        
        // Verify date picker appears
        expect(find.byType(CalendarDatePicker), findsOneWidget, reason: 'Date picker not shown');
        
        // Calculate date 10 days ago
        final today = DateTime.now();
        final tenDaysAgo = today.subtract(const Duration(days: 10));
        
        // Find the day number widget for 10 days ago and tap it
        final dayWidgets = find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.byType(Text),
        );
        
        // Tap on a day from the calendar (navigate to correct month if needed)
        bool dateFound = false;
        for (int i = 0; i < tester.widgetList(dayWidgets).length; i++) {
          final textWidget = tester.widget(dayWidgets.at(i)) as Text;
          if (textWidget.data == tenDaysAgo.day.toString()) {
            await tester.tap(dayWidgets.at(i));
            dateFound = true;
            break;
          }
        }
        
        // If date wasn't found in current month view, tap OK anyway
        if (!dateFound) {
          // Use today's date instead
          for (int i = 0; i < tester.widgetList(dayWidgets).length; i++) {
            final textWidget = tester.widget(dayWidgets.at(i)) as Text;
            if (textWidget.data == today.day.toString()) {
              await tester.tap(dayWidgets.at(i));
              break;
            }
          }
        }
        
        // Find and tap the OK button to confirm date selection
        final okButton = find.text('OK');
        await tester.tap(okButton);
        await tester.pumpAndSettle();
        
        // Verify "Created After" filter is applied
        final createdAfterFilter = find.widgetWithText(ElevatedButton, 'Created After');
        expect(createdAfterFilter, findsOneWidget, reason: 'Created After filter not displayed after selection');
      } 
      else {
        // Try to find "Created Before" if "Created After" is not available
        final cancelButton = find.text('Cancel');
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();
        
        // Tap Add filter again
        await tester.tap(addFilterButton);
        await tester.pumpAndSettle();
        
        final createdBeforeOption = find.descendant(
          of: find.byType(AlertDialog), 
          matching: find.text('Created Before')
        );
        
        if (tester.any(createdBeforeOption)) {
          await tester.tap(createdBeforeOption);
          await tester.pumpAndSettle();
          
          // Verify date picker appears
          expect(find.byType(CalendarDatePicker), findsOneWidget, reason: 'Date picker not shown');
          
          // Use today's date for Created Before
          final today = DateTime.now();
          
          // Find the day number widget for today and tap it
          final dayWidgets = find.descendant(
            of: find.byType(CalendarDatePicker),
            matching: find.byType(Text),
          );
          
          // Tap on today from the calendar
          for (int i = 0; i < tester.widgetList(dayWidgets).length; i++) {
            final textWidget = tester.widget(dayWidgets.at(i)) as Text;
            if (textWidget.data == today.day.toString()) {
              await tester.tap(dayWidgets.at(i));
              break;
            }
          }
          
          // Find and tap the OK button to confirm date selection
          final okButton = find.text('OK');
          await tester.tap(okButton);
          await tester.pumpAndSettle();
          
          // Verify "Created Before" filter is applied
          final createdBeforeFilter = find.widgetWithText(ElevatedButton, 'Created Before');
          expect(createdBeforeFilter, findsOneWidget, reason: 'Created Before filter not displayed after selection');
        }
      }
      
      // Now add an attribute filter
      await tester.tap(addFilterButton);
      await tester.pumpAndSettle();
      
      // Find the "Attribute Filters" section
      final attributeFiltersHeader = find.text('Attribute Filters');
      
      // Check if there are attribute filters available
      if (tester.any(attributeFiltersHeader)) {
        // Find all attribute filter options
        final attributeListTiles = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ListTile),
        );
        
        // Get all list tiles that aren't date filters
        final listTilesCount = tester.widgetList(attributeListTiles).length;
        
        // Find an attribute filter to tap (skip headers and date filters)
        bool attributeFilterFound = false;
        for (int i = 0; i < listTilesCount; i++) {
          // Check if this is an attribute filter by looking for count badge
          final containerInTile = find.descendant(
            of: attributeListTiles.at(i),
            matching: find.byType(Container),
          );
          
          if (tester.any(containerInTile)) {
            attributeFilterFound = true;
            await tester.tap(attributeListTiles.at(i));
            await tester.pumpAndSettle();
            break;
          }
        }
        
        if (attributeFilterFound) {
          // Now we should see a filter button created for the attribute
          // Find all filter buttons
          final filterButtons = find.descendant(
            of: find.byType(FiltersList),
            matching: find.byType(ElevatedButton),
          ).evaluate().where((element) {
            // Exclude "Add filter" button
            final buttonWidget = element.widget as ElevatedButton;
            final childWidget = buttonWidget.child;
            if (childWidget is Row) {
              return !childWidget.children.any((widget) => 
                widget is Text && widget.data == 'Add filter');
            }
            return true;
          });
          
          // Click on one of the attribute filter buttons to select values
          if (filterButtons.isNotEmpty) {
            await tester.tap(find.byWidget(filterButtons.first.widget));
            await tester.pumpAndSettle();
            
            // Verify checkbox dialog appears
            expect(find.byType(CheckboxListTile), findsWidgets, reason: 'Filter values dialog not shown');
            
            // Select the first checkbox
            final firstCheckbox = find.byType(CheckboxListTile).first;
            await tester.tap(firstCheckbox);
            await tester.pumpAndSettle();
            
            // Apply the filter selection
            final applyButton = find.text('Apply');
            await tester.tap(applyButton);
            await tester.pumpAndSettle();
            
            // Verify filter is applied - look for the number in parentheses showing selected values count
            final countBadge = find.text('(1)');
            expect(countBadge, findsOneWidget, reason: 'Filter selection count not displayed');
          }
        }
      }
      
      // Wait for filtered results to load
      await tester.pump(const Duration(seconds: 2));
    });
  });
  
}