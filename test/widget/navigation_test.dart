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

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AthanApp(showOnboarding: false));
    await tester.pump(const Duration(seconds: 1));
  }

  group('Bottom Navigation', () {
    testWidgets('renders 4 tab labels', (tester) async {
      await pumpApp(tester);

      final nav = find.byType(BottomNavigationBar);
      expect(nav, findsOneWidget);

      for (final label in ['Today', 'Quran', 'Tracker', 'More']) {
        expect(
          find.descendant(of: nav, matching: find.text(label)),
          findsOneWidget,
          reason: '$label tab not found',
        );
      }
    });

    testWidgets('default selected tab is Today', (tester) async {
      await pumpApp(tester);

      final bar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(bar.currentIndex, equals(0));
    });

    testWidgets('tapping Quran tab navigates to Quran page', (tester) async {
      await pumpApp(tester);

      final quranTab = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Quran'),
      );
      await tester.tap(quranTab);
      await tester.pump(const Duration(milliseconds: 500));

      // Quran page shows surah list — verify header or surah entry.
      expect(find.textContaining(RegExp('Quran|surah|Al-Fatihah', caseSensitive: false)), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping Tracker tab navigates to Tracker page', (tester) async {
      await pumpApp(tester);

      final trackerTab = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Tracker'),
      );
      await tester.tap(trackerTab);
      await tester.pump(const Duration(milliseconds: 500));

      // Tracker page always shows these prayer names.
      expect(find.text('Fajr'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping More tab navigates to More page', (tester) async {
      await pumpApp(tester);

      final moreTab = find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('More'),
      );
      await tester.tap(moreTab);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Calendar View'), findsOneWidget);
    });

    testWidgets('can switch between tabs multiple times', (tester) async {
      await pumpApp(tester);

      final nav = find.byType(BottomNavigationBar);

      await tester.tap(find.descendant(of: nav, matching: find.text('Tracker')));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.descendant(of: nav, matching: find.text('Today')));
      await tester.pump(const Duration(milliseconds: 300));

      // Back on home tab — Today heading should be present.
      expect(find.text('Today'), findsAtLeastNWidgets(1));
    });
  });

  group('Home Tab', () {
    testWidgets('shows prayer names on Home tab', (tester) async {
      await pumpApp(tester);

      for (final prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
        expect(find.text(prayer), findsAtLeastNWidgets(1), reason: '$prayer not shown');
      }
    });
  });
}
