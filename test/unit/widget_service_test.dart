import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:athan_call_to_success/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  group('WidgetService.cacheLocation', () {
    test('stores lat and lng', () async {
      await WidgetService.cacheLocation(1.3521, 103.8198);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('widget_cached_lat'), closeTo(1.3521, 0.0001));
      expect(prefs.getDouble('widget_cached_lng'), closeTo(103.8198, 0.0001));
    });

    test('stores city when provided', () async {
      await WidgetService.cacheLocation(1.3521, 103.8198, city: 'Singapore');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('widget_cached_city'), 'Singapore');
    });

    test('does not write city key when empty', () async {
      await WidgetService.cacheLocation(1.3521, 103.8198);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('widget_cached_city'), isNull);
    });

    test('overwrites previous city', () async {
      await WidgetService.cacheLocation(1.0, 2.0, city: 'Old City');
      await WidgetService.cacheLocation(1.0, 2.0, city: 'New City');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('widget_cached_city'), 'New City');
    });

    test('overwrites previous lat/lng', () async {
      await WidgetService.cacheLocation(10.0, 20.0);
      await WidgetService.cacheLocation(51.5, -0.12);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('widget_cached_lat'), closeTo(51.5, 0.0001));
      expect(prefs.getDouble('widget_cached_lng'), closeTo(-0.12, 0.0001));
    });
  });

  group('WidgetService.updateFromCache', () {
    test('completes without error when no cached location', () async {
      await expectLater(WidgetService.updateFromCache(), completes);
    });

    test('completes without error when cached location exists', () async {
      SharedPreferences.setMockInitialValues({
        'widget_cached_lat': 51.5,
        'widget_cached_lng': -0.12,
        'widget_cached_city': 'London',
      });
      await expectLater(WidgetService.updateFromCache(), completes);
    });

    test('completes without error with prayer log', () async {
      SharedPreferences.setMockInitialValues({
        'widget_cached_lat': 40.7128,
        'widget_cached_lng': -74.0060,
      });
      await expectLater(
        WidgetService.updateFromCache(prayerLog: {
          'Fajr': true,
          'Dhuhr': false,
          'Asr': true,
          'Maghrib': false,
          'Isha': false,
        }),
        completes,
      );
    });
  });

  group('WidgetService.updateAll', () {
    test('completes without error on non-Android platform', () async {
      await expectLater(
        WidgetService.updateAll(lat: 1.3521, lng: 103.8198),
        completes,
      );
    });

    test('completes without error with full params', () async {
      await expectLater(
        WidgetService.updateAll(
          lat: 1.3521,
          lng: 103.8198,
          city: 'Singapore',
          prayerLog: {'Fajr': true, 'Dhuhr': true, 'Asr': false, 'Maghrib': false, 'Isha': false},
        ),
        completes,
      );
    });
  });

  group('WidgetService.updateTrackerOnly', () {
    test('completes without error on non-Android platform', () async {
      await expectLater(
        WidgetService.updateTrackerOnly({'Fajr': true, 'Dhuhr': false, 'Asr': false, 'Maghrib': true, 'Isha': false}),
        completes,
      );
    });
  });
}
