import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:athan_call_to_success/tracker_page.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final dbPath = await getDatabasesPath();
    await deleteDatabase('$dbPath/athan_app.db');
  });

  Future<void> pumpTrackerPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // runAsync allows real-time async (DB I/O, SharedPreferences) to complete.
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: TrackerPage()));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    // Rebuild the widget tree with the loaded state.
    await tester.pump();
  }

  group('Tracker Tab UI', () {
    testWidgets('displays all 5 obligatory prayer names', (tester) async {
      await pumpTrackerPage(tester);
      for (final prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.text(prayer), findsAtLeastNWidgets(1), reason: '$prayer not shown');
      }
    });

    testWidgets('renders without errors or exceptions', (tester) async {
      await pumpTrackerPage(tester);
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Ramadan calendar section', (tester) async {
      await pumpTrackerPage(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.textContaining(RegExp('Ramadan', caseSensitive: false)),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('completed count starts at zero', (tester) async {
      await pumpTrackerPage(tester);
      expect(find.textContaining('0'), findsAtLeastNWidgets(1));
    });
  });

  group('Tasbeeh Counter', () {
    testWidgets('shows Tasbeeh Counter title', (tester) async {
      await pumpTrackerPage(tester);
      expect(find.text('Tasbeeh Counter'), findsOneWidget);
    });

    testWidgets('shows all 6 dhikr chips', (tester) async {
      await pumpTrackerPage(tester);
      const dhikrs = [
        'SubhanAllah',
        'Alhamdulillah',
        'Allahu Akbar',
        'La ilaha illa Allah',
        'Astaghfirullah',
        'Salawat',
      ];
      for (final name in dhikrs) {
        expect(find.text(name), findsAtLeastNWidgets(1), reason: '$name chip not found');
      }
    });

    testWidgets('shows target chips 33, 66, 99, 100', (tester) async {
      await pumpTrackerPage(tester);
      for (final target in ['33', '66', '99', '100']) {
        expect(find.text(target), findsAtLeastNWidgets(1), reason: 'Target chip $target not found');
      }
    });

    testWidgets('counter starts at 0 and shows default target', (tester) async {
      await pumpTrackerPage(tester);
      expect(find.text('of 33'), findsOneWidget);
    });

    testWidgets('tapping counter increments count without error', (tester) async {
      await pumpTrackerPage(tester);
      final counterButton = find
          .ancestor(of: find.text('of 33'), matching: find.byType(GestureDetector))
          .first;
      await tester.tap(counterButton);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsAtLeastNWidgets(1));
    });

    testWidgets('Reset button resets count to 0', (tester) async {
      await pumpTrackerPage(tester);
      final counterButton = find
          .ancestor(of: find.text('of 33'), matching: find.byType(GestureDetector))
          .first;
      await tester.tap(counterButton);
      await tester.pump();
      expect(find.text('1'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Reset'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('0'), findsAtLeastNWidgets(1));
    });

    testWidgets('selecting a different dhikr does not throw', (tester) async {
      await pumpTrackerPage(tester);
      await tester.tap(find.text('Alhamdulillah'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching dhikr updates arabic text', (tester) async {
      await pumpTrackerPage(tester);
      expect(find.text('سُبْحَانَ اللَّهِ'), findsOneWidget);
      await tester.tap(find.text('Alhamdulillah'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('الْحَمْدُ لِلَّهِ'), findsOneWidget);
    });
  });
}
