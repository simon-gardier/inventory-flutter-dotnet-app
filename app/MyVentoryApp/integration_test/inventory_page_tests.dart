import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_ventory_mobile/main.dart' as app;
import 'package:my_ventory_mobile/Controller/vertical_elements_list.dart';
import 'package:my_ventory_mobile/Controller/myventory_search_bar.dart';
import 'package:my_ventory_mobile/View/item_view_page.dart';
import 'dart:math';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Inventory Integration Tests', () {
    
    /// Login and wait for inventory page to load
    /// Handles the authentication flow and waits for the inventory page to load
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

    // Finds and returns a visible item name that can be used for testing
    // String? getVisibleItemName(WidgetTester tester) {
    //   final items = find.descendant(
    //     of: find.byType(VerticalElementsList),
    //     matching: find.byType(Text),
    //   );

    //   if (tester.any(items)) {
    //     final itemWidgets = tester.widgetList(items);

    //     List<String> validItems = [];

    //     for (var widget in itemWidgets) {
    //       final text = (widget as Text).data ?? '';
    //       if (text.isNotEmpty &&
    //           !text.contains('No location') &&
    //           !text.contains('Items') &&
    //           !text.contains('Location') &&
    //           !text.contains('Add filter')) {
    //         validItems.add(text);
    //       }
    //     }

    //     if (validItems.isNotEmpty) {
    //       final randomIndex = Random().nextInt(validItems.length);
    //       final randomItem = validItems[randomIndex];
    //       return randomItem;
    //     }
    //   }

    //   return null;
    // }
    String? getVisibleItemName(WidgetTester tester) {
      // Create a seed based on the current date (year, month, day)
      final now = DateTime.now();
      final seed = now.year * 10000 + now.month * 100 + now.day;
      final random = Random(seed);
            
      // First gets all item containers
      final itemContainers = find.descendant(
        of: find.byType(VerticalElementsList),
        matching: find.byType(InkWell),
      );
            
      List<String> suitableItems = [];
      List<int> suitableItemIndices = [];
      
      // Checks each item container
      for (int i = 0; i < tester.widgetList(itemContainers).length; i++) {
        // Look for badges with "B" or "L" text
        final badgeTexts = find.descendant(
          of: itemContainers.at(i),
          matching: find.textContaining(RegExp(r'^[BL]$')),
        );
        
        final fromTexts = find.descendant(
          of: itemContainers.at(i),
          matching: find.textContaining('From:'),
        );
        
        // Skips this item if it has a badge or "From:" text
        if (tester.any(badgeTexts) || tester.any(fromTexts)) {
          continue;
        }
        
        // Now looks for the item name
        final nameTexts = find.descendant(
          of: itemContainers.at(i),
          matching: find.byWidgetPredicate((widget) => 
            widget is Text && widget.style?.fontSize == 16
          ),
        );
        
        if (tester.any(nameTexts)) {
          final nameText = (tester.widget(nameTexts.first) as Text).data ?? '';
          if (nameText.isNotEmpty && nameText.length >= 3) {
            suitableItems.add(nameText);
            suitableItemIndices.add(i);
          }
        }
      }
      
      if (suitableItems.isNotEmpty) {
        final randomIndex = random.nextInt(suitableItems.length);
        final randomItem = suitableItems[randomIndex];
        return randomItem;
      } else {
        return null;
      }
    }
    
    // =====================================================================
    // TEST 1: SEARCH FUNCTIONALITY
    // =====================================================================
    // **Purpose:** Verify that users can search for items, view item details, and edit items successfully.
    // **Test Steps:**
    // 1. Login to the inventory page
    // 2. Get a random visible item name from the inventory list
    // 3. Extract a random substring from the item name to use as a search term
    // 4. Enter the search term in the search bar
    // 5. Tap on the first item in the search results
    // 6. Verify navigation to the item details page
    // 7. Scroll down and up to see all details
    // 8. Tap the edit button to enter edit mode
    // 9. Edit the item name by adding "Updated " prefix
    // 10. Edit the description field if available
    // 11. Increase quantity by tapping the increment button 3 times
    // 12. Save the changes
    // 13. Navigate back to the inventory page
    // 14. Verify successful return to inventory page
    // **What This Tests:**
    // - Search functionality
    // - Navigation to item details
    // - Scrolling in item details
    // - Item editing capability
    // - Saving changes
    // - Navigation back to inventory
    // In the 'Search, view and edit item test' function, we need to modify 
// how we find and tap the first item in the search results

  testWidgets('Search, view and edit item test', (WidgetTester tester) async {
    // Login and get to inventory page
    await loginToInventory(tester);
    
    // Get a visible item name to search for
    final itemName = getVisibleItemName(tester);
    
    if (itemName != null && itemName.isNotEmpty) {
      
      // Get a search substring from the item name
      final random = Random();
      final startIndex = random.nextInt(itemName.length);
      final maxLength = itemName.length - startIndex;
      final substringLength = max(1, random.nextInt(maxLength + 1)); // At least 1 character
      final searchChar = itemName.substring(startIndex, startIndex + substringLength);
      
      // Find and use the search bar
      final searchBar = find.descendant(
        of: find.byType(MyventorySearchBar),
        matching: find.byType(TextField),
      );
      
      expect(searchBar, findsOneWidget, reason: 'Search bar not found');
      
      await tester.tap(searchBar);
      await tester.pumpAndSettle();
      
      await tester.enterText(searchBar, searchChar);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      // Find items in the search results
      // Need to modify this part to skip borrowed or lent items
      
      // First get all item containers
      final itemContainers = find.descendant(
        of: find.byType(VerticalElementsList),
        matching: find.byType(InkWell), // Each item is wrapped in an InkWell for tap detection
      );
      
      if (tester.any(itemContainers)) {
        // Track suitable items (not borrowed or lent)
        List<Finder> suitableItemFinders = [];
        
        // Check each item container
        for (int i = 0; i < tester.widgetList(itemContainers).length; i++) {
          // Look for badges with "B" or "L" text
          final badgeTexts = find.descendant(
            of: itemContainers.at(i),
            matching: find.textContaining(RegExp(r'^[BL]$')),
          );
          
          // Also look for "From:" text which indicates borrowed items
          final fromTexts = find.descendant(
            of: itemContainers.at(i),
            matching: find.textContaining('From:'),
          );
          
          // Skip this item if it has a badge or "From:" text
          if (tester.any(badgeTexts) || tester.any(fromTexts)) {
            continue;
          }
          
          // This item doesn't have borrowing/lending indicators, it's suitable
          suitableItemFinders.add(itemContainers.at(i));
        }
        
        if (suitableItemFinders.isNotEmpty) {
          // Tap the first suitable item
          await tester.tap(suitableItemFinders.first);
          await tester.pumpAndSettle();
          
          // Verify we're on the item details page
          expect(find.byType(ItemViewPage), findsOneWidget, reason: 'Item details page not shown');
          
          // Scroll down to see all details
          await tester.dragFrom(
            tester.getCenter(find.byType(SingleChildScrollView).last),
            const Offset(0, -300)
          );
          await tester.pumpAndSettle();
          
          // Scroll back up
          await tester.dragFrom(
            tester.getCenter(find.byType(SingleChildScrollView).last),
            const Offset(0, 300)
          );
          await tester.pumpAndSettle();
          
          // Find and tap the edit button which now has text "Edit button"
          final editButton = find.text('Edit item');
          expect(editButton, findsOneWidget, reason: 'Edit button not found');
          await tester.tap(editButton);
          
          await tester.pumpAndSettle();
          
          // Check if we're in edit mode by finding text fields
          final titleFields = find.byType(TextField);
          expect(titleFields, findsWidgets, reason: 'No text fields found in edit mode');
          
          // Find the title field - this is more reliable than looking for a specific TextBox widget
          final titleField = titleFields.first;
          
          // Clear the text field first
          await tester.tap(titleField);
          await tester.pumpAndSettle();
          
          final updatedName = 'Updated $itemName';
          await tester.enterText(titleField, updatedName);
          await tester.pumpAndSettle();
          
          // Find and modify the description field - if there's at least a third text field
          if (tester.widgetList(titleFields).length > 2) {
            final descriptionField = titleFields.at(2);
            await tester.tap(descriptionField);
            await tester.pumpAndSettle();
            
            final newDescription = 'This description was updated during testing on ${DateTime.now().toString()}';
            await tester.enterText(descriptionField, newDescription);
            await tester.pumpAndSettle();
          }
          
          // Update quantity by tapping the + button multiple times
          final incrementButton = find.byIcon(Icons.add);
          if (tester.any(incrementButton)) {
            // Tap the increment button 3 times
            for (int i = 0; i < 3; i++) {
              await tester.tap(incrementButton.first, warnIfMissed: false);
              await tester.pump(const Duration(milliseconds: 100));
            }
            await tester.pumpAndSettle();
          }
          
          // Find and tap the "Update item" button 
          final updateItemButton = find.text('Update item');
          expect(updateItemButton, findsOneWidget, reason: 'Update item button not found');
          await tester.tap(updateItemButton);
          
          await tester.pumpAndSettle(const Duration(seconds: 2)); // Allow time for save operation
          
          // Navigate back to inventory page
          final backButton = find.byIcon(Icons.arrow_back);
          if (tester.any(backButton)) {
            await tester.tap(backButton, warnIfMissed: false);
            await tester.pumpAndSettle();
            
            // Verify we're back at the inventory page
            expect(find.byType(VerticalElementsList), findsOneWidget, reason: 'Did not return to inventory page');
          }
        } else {
          fail('No suitable items found after filtering out borrowed/lent items');
        }
      } else {
        fail('No items found with search term "$searchChar"');
      }
    } else {
      fail('No visible items found to test with');
    }
  });
    
    // =====================================================================
    // TEST 2: FILTER FUNCTIONALITY
    // =====================================================================
    // **Purpose:** Verify that users can add and apply multiple filters to narrow down the inventory list.
    // **Test Steps:**
    // 1. Login to the inventory page
    // 2. Tap the "Add filter" button
    // 3. Select the first filter option from the popup menu
    // 4. Tap on the filter button to open the selection dialog
    // 5. Select one or more checkbox values
    // 6. Apply the filter
    // 7. Verify the filter is applied and items are filtered
    // 8. Apply a second, different filter
    // 9. Verify both filters are applied
    // 10. Clean up by removing all applied filters
    // **What This Tests:**
    // - Filter menu functionality
    // - Filter selection dialog
    // - Applying multiple filters
    // - Filter removal
  
    // testWidgets('Add and apply multiple filters test', (WidgetTester tester) async {
    //   // Login and gets to inventory page
    //   await loginToInventory(tester);
      
    //   // Finds the "Add filter" button
    //   final addFilterBtn = find.text('Add filter');
    //   expect(addFilterBtn, findsOneWidget, reason: 'Add filter button not found');
      
    //   // Keeps track of applied filter names
    //   List<String> appliedFilterNames = [];
      
    //   // Taps the Add filter button
    //   await tester.tap(addFilterBtn);
    //   await tester.pumpAndSettle();
      
    //   // Now we should see an AlertDialog
    //   final filterDialog = find.byType(AlertDialog);
    //   expect(filterDialog, findsOneWidget, reason: 'Filter dialog not found');

    //   // Finds the "Attribute Filters" section header
    //   final attributeFiltersHeader = find.text('Attribute Filters');
    //   expect(attributeFiltersHeader, findsOneWidget, reason: 'Attribute Filters header not found');
      
    //   // Finds all ListTiles in the dialog
    //   final allListTiles = find.descendant(
    //     of: filterDialog,
    //     matching: find.byType(ListTile),
    //   );
      
    //   // Finds the first attribute filter (skip the date filters)
    //   String? firstFilterName;
    //   int attributeFilterIndex = -1;
      
    //   // Goes through all ListTiles
    //   for (int i = 0; i < tester.widgetList(allListTiles).length; i++) {
    //     // For each ListTile, find all Text widgets inside it
    //     final textsInListTile = find.descendant(
    //       of: allListTiles.at(i),
    //       matching: find.byType(Text),
    //     );
        
    //     // Analyzes all Text widgets to determine if this ListTile is an attribute filter
    //     bool isDateFilter = false;
    //     bool isHeader = false;
    //     String? potentialFilterName;
        
    //     for (int j = 0; j < tester.widgetList(textsInListTile).length; j++) {
    //       final textWidget = tester.widget(textsInListTile.at(j)) as Text;
    //       final text = textWidget.data;
          
    //       // Checks if this is a date filter or header
    //       if (text == 'Date Filters' || text == 'Attribute Filters' || 
    //           text == 'Cancel' || text == 'Select Filter') {
    //         isHeader = true;
    //       } else if (text != null && text.contains('Created')) {
    //         isDateFilter = true;
    //       } 
    //       // Check if it's not a number (which would be the count badge)
    //       else if (text != null && int.tryParse(text) == null) {
    //         potentialFilterName = text;
    //       }
    //     }
        
    //     // If this is not a date filter or header, it might be an attribute filter
    //     if (!isDateFilter && !isHeader && potentialFilterName != null) {
    //       firstFilterName = potentialFilterName;
    //       attributeFilterIndex = i;
    //       break;
    //     }
    //   }
      
    //   expect(attributeFilterIndex >= 0, true, reason: 'Could not find any attribute filter');
    //   expect(firstFilterName != null, true, reason: 'Could not extract filter name');
      
    //   // Select the first attribute filter
    //   await tester.tap(allListTiles.at(attributeFilterIndex));
    //   await tester.pumpAndSettle();
      
    //   // Now a filter button should be created with the selected filter name
    //   final firstFilterButton = find.widgetWithText(ElevatedButton, firstFilterName!);
    //   expect(firstFilterButton, findsOneWidget, reason: 'Filter button with name "$firstFilterName" was not created');
      
    //   // Taps on the filter button to open the dialog with checkboxes
    //   await tester.tap(firstFilterButton);
    //   await tester.pumpAndSettle();
      
    //   // Now we should see the dialog with checkboxes
    //   final checkboxes = find.byType(CheckboxListTile);
      
    //   if (tester.any(checkboxes)) {
    //     // Select at least one checkbox
    //     final checkboxCount = tester.widgetList(checkboxes).length;
    //     if (checkboxCount > 0) {
    //       await tester.tap(checkboxes.first);
    //       await tester.pumpAndSettle();
          
    //       // Applies the filter
    //       final applyBtn = find.text('Apply');
    //       expect(applyBtn, findsOneWidget, reason: 'Apply button not found');
          
    //       await tester.tap(applyBtn);
    //       await tester.pumpAndSettle();
          
    //       // Adds the filter name to our list
    //       appliedFilterNames.add(firstFilterName);
          
    //       // Applies a second filter
    //       await tester.tap(addFilterBtn);
    //       await tester.pumpAndSettle();
          
    //       // Finds the second filter dialog
    //       final secondFilterDialog = find.byType(AlertDialog);
    //       expect(secondFilterDialog, findsOneWidget, reason: 'Second filter dialog not found');
          
    //       // Gets all ListTiles in the second dialog
    //       final secondDialogListTiles = find.descendant(
    //         of: secondFilterDialog,
    //         matching: find.byType(ListTile),
    //       );
          
    //       // Finds a different attribute filter than the first one
    //       String? secondFilterName;
    //       int secondAttributeFilterIndex = -1;
          
    //       // Goes through all ListTiles in the second dialog
    //       for (int i = 0; i < tester.widgetList(secondDialogListTiles).length; i++) {
    //         // For each ListTile, find all Text widgets inside it
    //         final textsInSecondListTile = find.descendant(
    //           of: secondDialogListTiles.at(i),
    //           matching: find.byType(Text),
    //         );
            
    //         // Analyzes all Text widgets to determine if this ListTile is an attribute filter
    //         bool isDateFilter = false;
    //         bool isHeader = false;
    //         String? potentialFilterName;
            
    //         for (int j = 0; j < tester.widgetList(textsInSecondListTile).length; j++) {
    //           final textWidget = tester.widget(textsInSecondListTile.at(j)) as Text;
    //           final text = textWidget.data;
              
    //           // Checks if this is a date filter or header
    //           if (text == 'Date Filters' || text == 'Attribute Filters' || 
    //               text == 'Cancel' || text == 'Select Filter') {
    //             isHeader = true;
    //           } else if (text != null && text.contains('Created')) {
    //             isDateFilter = true;
    //           } 
    //           // Check if it's not a number (which would be the count badge)
    //           else if (text != null && int.tryParse(text) == null) {
    //             potentialFilterName = text;
    //           }
    //         }
            
    //         // If this is not a date filter or header and not the first filter, it might be a usable second filter
    //         if (!isDateFilter && !isHeader && potentialFilterName != null && 
    //             potentialFilterName != firstFilterName) {
    //           secondFilterName = potentialFilterName;
    //           secondAttributeFilterIndex = i;
    //           break;
    //         }
    //       }
          
    //       if (secondAttributeFilterIndex >= 0 && secondFilterName != null) {
    //         // Select the second attribute filter
    //         await tester.tap(secondDialogListTiles.at(secondAttributeFilterIndex));
    //         await tester.pumpAndSettle();
    //         // Findz the second filter button
    //         final secondFilterButton = find.widgetWithText(ElevatedButton, secondFilterName);
    //         expect(secondFilterButton, findsOneWidget, reason: 'Second filter button not found');
            
    //         // Taps the second filter button
    //         await tester.tap(secondFilterButton);
    //         await tester.pumpAndSettle();
            
    //         // Finds checkboxes in the second filter dialog
    //         final secondCheckboxes = find.byType(CheckboxListTile);
            
    //         if (tester.any(secondCheckboxes)) {
    //           // Selects at least one checkbox
    //           await tester.tap(secondCheckboxes.first);
    //           await tester.pumpAndSettle();
              
    //           // Applies the second filter
    //           final secondApplyBtn = find.text('Apply');
    //           expect(secondApplyBtn, findsOneWidget, reason: 'Apply button not found for second filter');
              
    //           await tester.tap(secondApplyBtn);
    //           await tester.pumpAndSettle();
              
    //           // Adds the second filter name to our list
    //           appliedFilterNames.add(secondFilterName);
    //         }
    //       }
    //     }
    //   }
      
    //   // Cleans up by removing all filters
    //   for (String filterName in appliedFilterNames) {
    //     // Find the filter button by its name
    //     final filterText = find.text(filterName);
        
    //     if (tester.any(filterText)) {
    //       // Find the parent button that contains this text
    //       final parentButton = find.ancestor(
    //         of: filterText,
    //         matching: find.byType(ElevatedButton)
    //       );
          
    //       if (tester.any(parentButton)) {
    //         // Find the close icon in the button
    //         final closeIcon = find.descendant(
    //           of: parentButton.first,
    //           matching: find.byIcon(Icons.close)
    //         );
            
    //         if (tester.any(closeIcon)) {
    //           await tester.tap(closeIcon.first);
    //           await tester.pumpAndSettle();
    //         } else {
    //           final buttonRect = tester.getRect(parentButton.first);
    //           final position = Offset(
    //             buttonRect.right - 10,
    //             buttonRect.center.dy
    //           );
    //           await tester.tapAt(position);
    //           await tester.pumpAndSettle();
    //         }
    //       }
    //     }
    //   }
    // });

    
    
    // =====================================================================
    // TEST 3: COMBINED FILTER AND SEARCH TEST
    // =====================================================================
    // **Purpose:** Verify that users can combine filtering and searching to precisely locate items.
    // **Test Steps:**
    // 1. Login to the inventory page
    // 2. Apply a filter by selecting a filter option and checkbox value
    // 3. Check if items are visible after filtering
    // 4. If items are visible, get a random item name from the filtered results
    // 5. Search for a substring of the selected item name
    // 6. Verify items are displayed after combined filtering and searching
    // 7. Tap on the first item to view details
    // 8. Verify navigation to the item details page
    // 9. Scroll to see details
    // 10. Navigate back to inventory page
    // 11. Clean up by clearing search and removing filters
    // **What This Tests:**
    // - Combined use of filters and search
    // - Navigation from filtered results
    // - Filter and search cleanup
    // testWidgets('Filter and search combined test', (WidgetTester tester) async {
    //   // Login and get to inventory page
    //   await loginToInventory(tester);
      
    //   // Applies a filter first
    //   final addFilterBtn = find.text('Add filter');
    //   expect(addFilterBtn, findsOneWidget, reason: 'Add filter button not found');
      
    //   await tester.tap(addFilterBtn);
    //   await tester.pumpAndSettle();
      
    //   // Now we should see an AlertDialog
    //   final filterDialog = find.byType(AlertDialog);
    //   expect(filterDialog, findsOneWidget, reason: 'Filter dialog not found');

    //   // Finds the "Attribute Filters" section header
    //   final attributeFiltersHeader = find.text('Attribute Filters');
    //   expect(attributeFiltersHeader, findsOneWidget, reason: 'Attribute Filters header not found');
      
    //   // Finds all ListTiles in the dialog
    //   final allListTiles = find.descendant(
    //     of: filterDialog,
    //     matching: find.byType(ListTile),
    //   );
      
    //   // Finds the first attribute filter (skip the date filters)
    //   String? firstFilterName;
    //   int attributeFilterIndex = -1;
      
    //   // Goes through all ListTiles
    //   for (int i = 0; i < tester.widgetList(allListTiles).length; i++) {
    //     final textsInListTile = find.descendant(
    //       of: allListTiles.at(i),
    //       matching: find.byType(Text),
    //     );
        
    //     // Analyze all Text widgets to determine if this ListTile is an attribute filter
    //     bool isDateFilter = false;
    //     bool isHeader = false;
    //     String? potentialFilterName;
        
    //     for (int j = 0; j < tester.widgetList(textsInListTile).length; j++) {
    //       final textWidget = tester.widget(textsInListTile.at(j)) as Text;
    //       final text = textWidget.data;
    //       // Check if this is a date filter or header
    //       if (text == 'Date Filters' || text == 'Attribute Filters' || 
    //           text == 'Cancel' || text == 'Select Filter') {
    //         isHeader = true;
    //       } else if (text != null && text.contains('Created')) {
    //         isDateFilter = true;
    //       } 
    //       // Checks if it's not a number (which would be the count badge)
    //       else if (text != null && int.tryParse(text) == null) {
    //         potentialFilterName = text;
    //       }
    //     }
        
    //     // If this is not a date filter or header, it might be an attribute filter
    //     if (!isDateFilter && !isHeader && potentialFilterName != null) {
    //       firstFilterName = potentialFilterName;
    //       attributeFilterIndex = i;
    //       break;
    //     }
    //   }
      
    //   expect(attributeFilterIndex >= 0, true, reason: 'Could not find any attribute filter');
    //   expect(firstFilterName != null, true, reason: 'Could not extract filter name');
      
    //   // Selects the first attribute filter
    //   await tester.tap(allListTiles.at(attributeFilterIndex));
    //   await tester.pumpAndSettle();
      
    //   // Now a filter button should be created with the selected filter name
    //   final firstFilterButton = find.widgetWithText(ElevatedButton, firstFilterName!);
    //   expect(firstFilterButton, findsOneWidget, reason: 'Filter button with name "$firstFilterName" was not created');
      
    //   // Taps on the filter button to open the dialog with checkboxes
    //   await tester.tap(firstFilterButton);
    //   await tester.pumpAndSettle();
      
    //   // Now we should see the dialog with checkboxes
    //   final checkboxes = find.byType(CheckboxListTile);
      
    //   if (tester.any(checkboxes)) {
    //     // Selects the first checkbox
    //     await tester.tap(checkboxes.first);
    //     await tester.pumpAndSettle();
        
    //     // Applies the filter
    //     final applyBtn = find.text('Apply');
    //     if (tester.any(applyBtn)) {
    //       await tester.tap(applyBtn);
    //       await tester.pumpAndSettle();
          
    //       // Checks if any items are visible after filtering
    //       final filteredItems = find.descendant(
    //         of: find.byType(VerticalElementsList),
    //         matching: find.byType(GestureDetector),
    //       );
          
    //       if (!tester.any(filteredItems)) {
    //         // If no items visible, remove the filter and skip search part
    //         final filterText = find.text(firstFilterName);
    //         if (tester.any(filterText)) {
    //           final parentButton = find.ancestor(
    //             of: filterText,
    //             matching: find.byType(ElevatedButton)
    //           );
              
    //           if (tester.any(parentButton)) {
    //             final closeIcon = find.descendant(
    //               of: parentButton.first,
    //               matching: find.byIcon(Icons.close)
    //             );
                
    //             if (tester.any(closeIcon)) {
    //               await tester.tap(closeIcon.first);
    //               await tester.pumpAndSettle();
    //             } else {
    //               // Tries to tap where the close icon should be
    //               final buttonRect = tester.getRect(parentButton.first);
    //               final position = Offset(
    //                 buttonRect.right - 10,
    //                 buttonRect.center.dy
    //               );
    //               await tester.tapAt(position);
    //               await tester.pumpAndSettle();
    //             }
    //           }
    //         }
    //       } else {
    //         // Gets a visible item name from filtered results to use in search
    //         final itemTexts = find.descendant(
    //           of: find.byType(VerticalElementsList),
    //           matching: find.byType(Text),
    //         );
            
    //         List<String> visibleItemNames = [];
    //         for (var widget in tester.widgetList(itemTexts)) {
    //           final text = (widget as Text).data ?? '';
    //           if (text.isNotEmpty && 
    //               text.length > 2 &&
    //               !text.contains('No location') &&
    //               !text.contains('Items') &&
    //               !text.contains('Location') &&
    //               !text.contains('Add filter')) {
    //             visibleItemNames.add(text);
    //           }
    //         }
            
    //         if (visibleItemNames.isNotEmpty) {
    //           final randomIndex = Random().nextInt(visibleItemNames.length);
    //           final itemToSearch = visibleItemNames[randomIndex];
              
    //           // Now searches for a substring of the selected item
    //           final searchBar = find.descendant(
    //             of: find.byType(MyventorySearchBar),
    //             matching: find.byType(TextField),
    //           );
              
    //           expect(searchBar, findsOneWidget, reason: 'Search bar not found');
              
    //           await tester.tap(searchBar);
    //           await tester.pumpAndSettle();
              
    //           // Generates a random substring to search for
    //           String searchText;
    //           if (itemToSearch.length <= 3) {
    //             searchText = itemToSearch;
    //           } else {
    //             final random = Random();
    //             final startIndex = random.nextInt(itemToSearch.length - 2);
    //             final length = random.nextInt(itemToSearch.length - startIndex - 1) + 1;
    //             searchText = itemToSearch.substring(startIndex, startIndex + length);
    //           }
              
    //           await tester.enterText(searchBar, searchText);
    //           await tester.pumpAndSettle(const Duration(seconds: 2));
              
    //           // Checks if any items are visible after filtering and searching
    //           final filteredAndSearchedItems = find.descendant(
    //             of: find.byType(VerticalElementsList),
    //             matching: find.byType(GestureDetector),
    //           );
              
    //           if (tester.any(filteredAndSearchedItems)) {
    //             // Click on the first item to view details
    //             await tester.tap(filteredAndSearchedItems.first);
    //             await tester.pumpAndSettle();
                
    //             // Verifies we're on the item details page
    //             expect(find.byType(ItemViewPage), findsOneWidget, reason: 'Item details page not shown');
                
    //             // Scrolls down to see all details
    //             await tester.dragFrom(
    //               tester.getCenter(find.byType(SingleChildScrollView).last),
    //               const Offset(0, -300)
    //             );
    //             await tester.pumpAndSettle();
                
    //             // Navigates back to inventory page
    //             final backButton = find.byIcon(Icons.arrow_back);
    //             if (tester.any(backButton)) {
    //               await tester.tap(backButton, warnIfMissed: false);
    //               await tester.pumpAndSettle();
    //             }
    //           } else {
    //             // Do nothing
    //           }
    //         } else {
    //           // Do nothing
    //         }
    //       }
    //     }
    //   }
      
    //   // Cleans up - clear search and remove filters
    //   final searchBar = find.descendant(
    //     of: find.byType(MyventorySearchBar),
    //     matching: find.byType(TextField),
    //   );
      
    //   if (tester.any(searchBar)) {
    //     await tester.tap(searchBar);
    //     await tester.pumpAndSettle();
        
    //     await tester.enterText(searchBar, '');
    //     await tester.pumpAndSettle(const Duration(seconds: 1));
    //   }
      
    //   // Removes any active filters
    //   final filterText = find.text(firstFilterName);
    //   if (tester.any(filterText)) {
    //     final parentButton = find.ancestor(
    //       of: filterText,
    //       matching: find.byType(ElevatedButton)
    //     );
        
    //     if (tester.any(parentButton)) {
    //       final closeIcon = find.descendant(
    //         of: parentButton.first,
    //         matching: find.byIcon(Icons.close)
    //       );
          
    //       if (tester.any(closeIcon)) {
    //         await tester.tap(closeIcon.first);
    //         await tester.pumpAndSettle();
    //       } else {
    //         // Tries to tap where the close icon should be
    //         final buttonRect = tester.getRect(parentButton.first);
    //         final position = Offset(
    //           buttonRect.right - 10,
    //           buttonRect.center.dy
    //         );
    //         await tester.tapAt(position);
    //         await tester.pumpAndSettle();
    //       }
    //     }
    //   }
    // });
    
    // // =====================================================================
    // // TEST 4: DELETE ITEM THEN LOOKUP
    // // =====================================================================
    // // **Purpose:** Verify that users can delete items and that deleted items are removed from the inventory.
    // // **Test Steps:**
    // // 1. Login to the inventory page
    // // 2. Get the name of an item to delete
    // // 3. Tap on the item to view its details
    // // 4. Tap the "Delete Item" button
    // // 5. Confirm deletion in the confirmation dialog
    // // 6. Verify return to the inventory page
    // // 7. Search for the deleted item by name
    // // 8. Verify the "No items found" message appears, confirming the item was deleted

    // // **What This Tests:**
    // // - Item deletion flow
    // // - Deletion confirmation dialog
    // // - Verification that deleted items cannot be found
    // testWidgets('Delete item and verify it\'s gone', (WidgetTester tester) async {
    //   // Login and get to inventory page
    //   await loginToInventory(tester);
      
    //   // Find and select the first item in the list
    //   final items = find.descendant(
    //     of: find.byType(VerticalElementsList),
    //     matching: find.byType(GestureDetector),
    //   );
      
    //   expect(items, findsWidgets, reason: 'No items found in inventory list');
      
    //   // Gets the name of the first item before deleting it
    //   String itemName = '';
    //   final itemTexts = find.descendant(
    //     of: find.byType(VerticalElementsList),
    //     matching: find.byType(Text),
    //   );
      
    //   for (var widget in tester.widgetList(itemTexts)) {
    //     final text = (widget as Text).data ?? '';
    //     if (text.isNotEmpty &&
    //         !text.contains('No location') &&
    //         !text.contains('Items') &&
    //         !text.contains('Location') &&
    //         !text.contains('Add filter')) {
    //       itemName = text;
    //       break;
    //     }
    //   }
      
    //   expect(itemName.isNotEmpty, true, reason: 'Could not find an item name to use for deletion test');
      
    //   // Taps on the first item to open its details
    //   await tester.tap(items.first);
    //   await tester.pumpAndSettle();
      
    //   // Verify we're on the item details page
    //   expect(find.byType(ItemViewPage), findsOneWidget, reason: 'Item details page not shown');
      
    //   // Try to find the delete button using multiple strategies
    //   final deleteOutlineIcon = find.byIcon(Icons.delete_outline);
      
    //   if (tester.any(deleteOutlineIcon)) {
    //     await tester.tap(deleteOutlineIcon.first);
    //   } else {
    //     final deleteTooltip = find.byTooltip('Delete Item');
        
    //     if (tester.any(deleteTooltip)) {
    //       await tester.tap(deleteTooltip.first);
    //     } else {
    //       final appBarIconButtons = find.descendant(
    //         of: find.byType(AppBar).last,
    //         matching: find.byType(IconButton),
    //       );
          
    //       if (!tester.any(appBarIconButtons)) {
    //         final allIconButtons = find.byType(IconButton);
            
    //         if (tester.any(allIconButtons)) {
    //           for (int i = tester.widgetList(allIconButtons).length - 1; i >= 0; i--) {
    //             await tester.tap(allIconButtons.at(i));
    //             await tester.pumpAndSettle();
                
    //             if (tester.any(find.text('Delete Item')) || 
    //                 tester.any(find.text('Are you sure')) ||
    //                 tester.any(find.text('Delete'))) {
    //               break;
    //             }
    //           }
    //         } else {
    //           fail('Could not find any IconButtons');
    //         }
    //       } else {
    //         await tester.tap(appBarIconButtons.last);
    //       }
    //     }
    //   }
      
    //   await tester.pumpAndSettle();
      
    //   // Finds and taps the confirmation dialog's "Delete" button
    //   final confirmDeleteButton = find.widgetWithText(TextButton, 'Delete');
    //   expect(confirmDeleteButton, findsOneWidget, reason: 'Delete confirmation button not found');
      
    //   await tester.tap(confirmDeleteButton);
    //   await tester.pumpAndSettle(const Duration(seconds: 2));
      
    //   // Verifies we're back at the inventory page
    //   expect(find.byType(VerticalElementsList), findsOneWidget, reason: 'Did not return to inventory page after deletion');
      
    //   // Searches for the deleted item to verify it's gone
    //   final searchBar = find.descendant(
    //     of: find.byType(MyventorySearchBar),
    //     matching: find.byType(TextField),
    //   );
      
    //   expect(searchBar, findsOneWidget, reason: 'Search bar not found');
      
    //   await tester.tap(searchBar);
    //   await tester.pumpAndSettle();
      
    //   await tester.enterText(searchBar, itemName);
    //   await tester.pumpAndSettle();
      
    //   // Uses progressive waiting to ensure "No items found" message appears
    //   await tester.pump(const Duration(seconds: 1));
      
    //   bool noItemsFoundDisplayed = false;
    //   for (int i = 0; i < 5; i++) {
    //     await tester.pump(const Duration(seconds: 1));
    //     if (tester.any(find.text('No items found'))) {
    //       noItemsFoundDisplayed = true;
    //       break;
    //     }
    //   }
      
    //   if (!noItemsFoundDisplayed) {
    //     await tester.pumpAndSettle(const Duration(seconds: 2));
    //   }
      
    //   // Verifies "No items found" message is displayed
    //   final noItemsFound = find.text('No items found');
    //   expect(noItemsFound, findsOneWidget, reason: 'Expected "No items found" message not displayed');
    // });
  });
}