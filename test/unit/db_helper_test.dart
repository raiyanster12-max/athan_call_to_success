import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:athan_call_to_success/db_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Always start each test with a clean in-memory database.
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/athan_app.db';
    await deleteDatabase(path);
  });

  // ── Masjid CRUD ────────────────────────────────────────────────────────────

  group('Masjid CRUD', () {
    test('insertMasjid and getMasjids returns inserted row', () async {
      final masjid = {
        'id': 'msj-001',
        'name': 'Al-Salam',
        'address': '123 Main St',
        'lat': 40.71,
        'lng': -74.00,
      };
      await DBHelper.insertMasjid(masjid);
      final results = await DBHelper.getMasjids();
      expect(results.length, equals(1));
      expect(results.first['name'], equals('Al-Salam'));
    });

    test('insertMasjid replaces duplicate id', () async {
      final original = {'id': 'msj-001', 'name': 'Original', 'address': '', 'lat': 0.0, 'lng': 0.0};
      final updated = {'id': 'msj-001', 'name': 'Updated', 'address': '', 'lat': 0.0, 'lng': 0.0};
      await DBHelper.insertMasjid(original);
      await DBHelper.insertMasjid(updated);
      final results = await DBHelper.getMasjids();
      expect(results.length, equals(1));
      expect(results.first['name'], equals('Updated'));
    });

    test('deleteMasjid removes the row', () async {
      await DBHelper.insertMasjid({'id': 'msj-001', 'name': 'Test', 'address': '', 'lat': 0.0, 'lng': 0.0});
      await DBHelper.deleteMasjid('msj-001');
      final results = await DBHelper.getMasjids();
      expect(results, isEmpty);
    });

    test('getMasjids returns empty list when no favorites saved', () async {
      final results = await DBHelper.getMasjids();
      expect(results, isEmpty);
    });
  });

  // ── Prayer Logs ────────────────────────────────────────────────────────────

  group('Prayer Logs', () {
    const dateKey = '2025-06-15';

    test('getPrayerLogForDate returns empty map for unknown date', () async {
      final log = await DBHelper.getPrayerLogForDate(dateKey);
      expect(log, isEmpty);
    });

    test('setPrayerCompleted true persists as completed', () async {
      await DBHelper.setPrayerCompleted(
        dateKey: dateKey,
        prayerName: 'Fajr',
        completed: true,
      );
      final log = await DBHelper.getPrayerLogForDate(dateKey);
      expect(log['Fajr'], isTrue);
    });

    test('setPrayerCompleted false persists as not completed', () async {
      await DBHelper.setPrayerCompleted(
        dateKey: dateKey,
        prayerName: 'Fajr',
        completed: false,
      );
      final log = await DBHelper.getPrayerLogForDate(dateKey);
      expect(log['Fajr'], isFalse);
    });

    test('overwrite prayer status from true to false', () async {
      await DBHelper.setPrayerCompleted(dateKey: dateKey, prayerName: 'Dhuhr', completed: true);
      await DBHelper.setPrayerCompleted(dateKey: dateKey, prayerName: 'Dhuhr', completed: false);
      final log = await DBHelper.getPrayerLogForDate(dateKey);
      expect(log['Dhuhr'], isFalse);
    });

    test('multiple prayers on same date stored independently', () async {
      await DBHelper.setPrayerCompleted(dateKey: dateKey, prayerName: 'Fajr', completed: true);
      await DBHelper.setPrayerCompleted(dateKey: dateKey, prayerName: 'Dhuhr', completed: false);
      await DBHelper.setPrayerCompleted(dateKey: dateKey, prayerName: 'Asr', completed: true);
      final log = await DBHelper.getPrayerLogForDate(dateKey);
      expect(log['Fajr'], isTrue);
      expect(log['Dhuhr'], isFalse);
      expect(log['Asr'], isTrue);
    });
  });

  // ── App Settings ───────────────────────────────────────────────────────────

  group('App Settings', () {
    test('getSetting returns null for unknown key', () async {
      final value = await DBHelper.getSetting('nonexistent_key');
      expect(value, isNull);
    });

    test('setSetting and getSetting round-trips value', () async {
      await DBHelper.setSetting('theme', 'dark');
      final value = await DBHelper.getSetting('theme');
      expect(value, equals('dark'));
    });

    test('setSetting overwrites existing value', () async {
      await DBHelper.setSetting('theme', 'light');
      await DBHelper.setSetting('theme', 'dark');
      final value = await DBHelper.getSetting('theme');
      expect(value, equals('dark'));
    });
  });

  // ── Pinned Masjid ──────────────────────────────────────────────────────────

  group('Pinned Masjid', () {
    test('getPinnedMasjid returns null when nothing pinned', () async {
      final pinned = await DBHelper.getPinnedMasjid();
      expect(pinned, isNull);
    });

    test('setPinnedMasjid and getPinnedMasjid returns correct data', () async {
      await DBHelper.setPinnedMasjid(
        id: 'pin-001',
        name: 'Masjid Al-Salam',
        address: '123 Peace St',
        lat: 40.71,
        lng: -74.00,
      );
      final pinned = await DBHelper.getPinnedMasjid();
      expect(pinned, isNotNull);
      expect(pinned!['id'], equals('pin-001'));
      expect(pinned['name'], equals('Masjid Al-Salam'));
      expect(pinned['lat'], closeTo(40.71, 0.001));
      expect(pinned['lng'], closeTo(-74.00, 0.001));
    });

    test('clearPinnedMasjid removes pinned data', () async {
      await DBHelper.setPinnedMasjid(
        id: 'pin-001',
        name: 'Test Masjid',
        address: '',
        lat: 0.0,
        lng: 0.0,
      );
      await DBHelper.clearPinnedMasjid();
      final pinned = await DBHelper.getPinnedMasjid();
      expect(pinned, isNull);
    });
  });

  // ── Iqamah Settings ────────────────────────────────────────────────────────

  group('Iqamah Settings', () {
    test('getIqamahSettings returns defaults when nothing stored', () async {
      final settings = await DBHelper.getIqamahSettings();
      expect(settings['fajr'], equals(30));
      expect(settings['dhuhr'], equals(15));
      expect(settings['asr'], equals(15));
      expect(settings['maghrib'], equals(10));
      expect(settings['isha'], equals(15));
      expect(settings['jumaa1'], equals('13:45'));
      expect(settings['jumaa2'], equals('15:15'));
    });

    test('setIqamahSettings persists and getIqamahSettings reads back', () async {
      await DBHelper.setIqamahSettings({
        'fajr': 20,
        'dhuhr': 10,
        'asr': 10,
        'maghrib': 5,
        'isha': 20,
        'jumaa1': '12:30',
        'jumaa2': '14:00',
      });
      final settings = await DBHelper.getIqamahSettings();
      expect(settings['fajr'], equals(20));
      expect(settings['dhuhr'], equals(10));
      expect(settings['jumaa1'], equals('12:30'));
    });
  });

  // ── Export / Import ────────────────────────────────────────────────────────

  group('Export and Import Tracker Data', () {
    test('export contains correct structure', () async {
      await DBHelper.setPrayerCompleted(
        dateKey: '2025-06-15',
        prayerName: 'Fajr',
        completed: true,
      );
      final export = await DBHelper.exportTrackerData();
      expect(export['type'], equals('athan_tracker_backup'));
      expect(export['version'], equals(1));
      expect(export['prayerStatusByDate'], isA<Map>());
      final prayerData = export['prayerStatusByDate'] as Map;
      expect(prayerData['2025-06-15']?['Fajr'], isTrue);
    });

    test('import replaces existing data when replaceExisting is true', () async {
      await DBHelper.setPrayerCompleted(
        dateKey: '2025-06-15',
        prayerName: 'Fajr',
        completed: true,
      );
      final payload = {
        'type': 'athan_tracker_backup',
        'version': 1,
        'prayerStatusByDate': {
          '2025-06-15': {'Fajr': false, 'Dhuhr': true},
        },
        'ramadanStatusByYear': {},
      };
      await DBHelper.importTrackerData(payload, replaceExisting: true);
      final log = await DBHelper.getPrayerLogForDate('2025-06-15');
      expect(log['Fajr'], isFalse);
      expect(log['Dhuhr'], isTrue);
    });

    test('round-trip export then import preserves all prayer statuses', () async {
      await DBHelper.setPrayerCompleted(dateKey: '2025-06-15', prayerName: 'Fajr', completed: true);
      await DBHelper.setPrayerCompleted(dateKey: '2025-06-15', prayerName: 'Isha', completed: false);
      final export = await DBHelper.exportTrackerData();

      // Clear and re-import.
      final dbPath = await getDatabasesPath();
      await deleteDatabase('$dbPath/athan_app.db');
      await DBHelper.importTrackerData(export, replaceExisting: true);

      final log = await DBHelper.getPrayerLogForDate('2025-06-15');
      expect(log['Fajr'], isTrue);
      expect(log['Isha'], isFalse);
    });
  });

  // ── deleteAllData ──────────────────────────────────────────────────────────

  group('deleteAllData', () {
    test('clears all tables', () async {
      await DBHelper.insertMasjid({'id': 'm1', 'name': 'Test', 'address': '', 'lat': 0.0, 'lng': 0.0});
      await DBHelper.setPrayerCompleted(dateKey: '2025-01-01', prayerName: 'Fajr', completed: true);
      await DBHelper.setSetting('theme', 'dark');

      await DBHelper.deleteAllData();

      expect(await DBHelper.getMasjids(), isEmpty);
      expect(await DBHelper.getPrayerLogForDate('2025-01-01'), isEmpty);
      expect(await DBHelper.getSetting('theme'), isNull);
    });
  });
}
