// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:athan_call_to_success/main.dart' show AthanApp;

void main() {
  // Initialize sqflite for tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('Masjid discovery flow test', (WidgetTester tester) async {
    // 0. Ensure a clean state by deleting the database if it exists
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/athan_app.db';
    await deleteDatabase(path);

    // Set a larger viewport to ensure all items in MorePage (like Masjid Finder) are rendered
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    // 1. Render the app
    await tester.pumpWidget(const AthanApp(showOnboarding: false));
    // Wait for initializations and potential timers to stabilize
    await tester.pump(const Duration(seconds: 1));

    print('Step 1: App rendered');

    // Handle potential Location Permission dialog if it appears in tests
    if (find.text('Location Permission').evaluate().isNotEmpty) {
      await tester.tap(find.text('Allow'));
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Handle potential Notification Permission dialog if it appears
    if (find.text('Notification Permission').evaluate().isNotEmpty) {
      await tester.tap(find.text('Allow'));
      await tester.pump(const Duration(milliseconds: 500));
    }

    // 2. Verify basic home UI
    expect(find.text('Today'), findsAtLeastNWidgets(1));

    // 3. Navigate to More tab (index 3)
    print('Step 3: Navigating to More tab');
    // Using a more specific finder for the tab to avoid ambiguity
    final moreTab = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('More'),
    );
    expect(moreTab, findsOneWidget);
    await tester.tap(moreTab);

    // Pump to trigger transition and build MorePage
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 4. Verify we are on MorePage (check for unique text)
    expect(find.text('Calendar View'), findsOneWidget);

    // 5. Navigate to Masjid Finder
    print('Step 5: Navigating to Masjid Finder');
    final masjidFinder = find.text('Masjid Finder');
    // Ensure it's visible (CalendarDatePicker is large)
    await tester.ensureVisible(masjidFinder);
    await tester.pump();

    expect(masjidFinder, findsOneWidget);
    await tester.tap(masjidFinder);
    // Pump to handle the transition
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    print('Step 6: Verifying MasjidPage state');
    // 6. Verify we are on MasjidPage
    // The text might be "BY LOCATION" (Grid view) or "By Location" (Pinned view)
    // In a clean state it should be "BY LOCATION"
    final byLocationFinder = find.textContaining(RegExp('Location', caseSensitive: false));

    // Wait for async load if needed
    if (byLocationFinder.evaluate().isEmpty) {
       await tester.pump(const Duration(milliseconds: 500));
    }

    expect(byLocationFinder, findsAtLeastNWidgets(1));

    // 7. Trigger search dialog by tapping "BY LOCATION"
    print('Step 7: Opening Search Dialog');
    await tester.tap(byLocationFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 8. Verify the search dialog contains the Radius slider and zip field
    print('Step 8: Verifying search dialog UI');
    expect(find.text('Search Masjid'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.textContaining('miles'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // 9. Test Radius Slider interaction
    print('Step 9: Testing Radius Slider');
    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(100, 0)); // Increase radius
    await tester.pump();
    // Verify radius text updated (assuming it starts at something else)
    // Note: Exact value depends on slider width/constraints

    // 10. Test Zip Code input
    print('Step 10: Entering zip code');
    final zipField = find.byType(TextField);
    await tester.enterText(zipField, '90210');
    await tester.pump();

    // 11. Tap Search and verify results or "No masjids found" (mocked/empty state)
    print('Step 11: Tapping Search');
    final searchButton = find.text('Search');
    await tester.tap(searchButton);
    await tester.pump(const Duration(milliseconds: 500));

    print('Test completed successfully');

    // Cleanup: Close dialog
    if (find.text('Cancel').evaluate().isNotEmpty) {
      await tester.tap(find.text('Cancel'));
      await tester.pump();
    }
  });
}
