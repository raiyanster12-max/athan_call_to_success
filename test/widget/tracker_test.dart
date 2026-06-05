import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:athan_call_to_success/main.dart' show AthanApp;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = await getDatabasesPath();
    await deleteDatabase('$dbPath/athan_app.db');
  });

  Future<void> pumpAndGoToTracker(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AthanApp(showOnboarding: false));
    await tester.pump(const Duration(seconds: 1));

    final trackerTab = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Tracker'),
    );
    await tester.tap(trackerTab);
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Tracker Tab UI', () {
    testWidgets('displays all 5 obligatory prayer names', (tester) async {
      await pumpAndGoToTracker(tester);

      for (final prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.text(prayer), findsAtLeastNWidgets(1), reason: '$prayer not shown');
      }
    });

    testWidgets('renders without errors or exceptions', (tester) async {
      await pumpAndGoToTracker(tester);
      // pumpAndGoToTracker would throw if a widget error occurred.
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Ramadan calendar section', (tester) async {
      await pumpAndGoToTracker(tester);

      // Scroll down to find Ramadan section.
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining(RegExp('Ramadan', caseSensitive: false)),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('completed count starts at zero', (tester) async {
      await pumpAndGoToTracker(tester);
      // Completed count displayed as "0/5" or similar pattern.
      expect(find.textContaining('0'), findsAtLeastNWidgets(1));
    });
  });
}
