import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static const String trackerPrayerKeyPrefix = 'prayer_status_date_';
  static const String trackerRamadanKeyPrefix = 'ramadan_status_year_';

  /// Notifier to alert listeners (like HomePage) when the pinned masjid changes.
  static final ChangeNotifier pinnedChangeNotifier = ChangeNotifier();

  @visibleForTesting
  static String? testDatabasePath;

  static Future<void> _createFavoriteMasjidsTable(Database db) async {
    await db.execute(
      'CREATE TABLE favorite_masjids(id TEXT PRIMARY KEY, name TEXT, address TEXT, lat REAL, lng REAL)',
    );
  }

  static Future<void> _createPrayerLogsTable(Database db) async {
    await db.execute(
      'CREATE TABLE prayer_logs(date_key TEXT NOT NULL, prayer_name TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(date_key, prayer_name))',
    );
  }

  static Future<void> _createSettingsTable(Database db) async {
    await db.execute(
      'CREATE TABLE app_settings(setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)',
    );
  }

  static Future<Database> database() async {
    final dbPath = testDatabasePath ?? await getDatabasesPath();
    final name = testDatabasePath == inMemoryDatabasePath ? '' : 'athan_app.db';
    return openDatabase(
      join(dbPath, name),
      onCreate: (db, version) async {
        await _createFavoriteMasjidsTable(db);
        await _createPrayerLogsTable(db);
        await _createSettingsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createPrayerLogsTable(db);
        }
        if (oldVersion < 3) {
          await _createSettingsTable(db);
        }
      },
      version: 3,
    );
  }

  static Future<void> insertMasjid(Map<String, dynamic> data) async {
    final db = await DBHelper.database();
    await db.insert(
      'favorite_masjids',
      data,
      // ConflictAlgorithm is part of the sqflite.dart import
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getMasjids() async {
    final db = await DBHelper.database();
    return db.query('favorite_masjids');
  }

  static Future<void> deleteMasjid(String id) async {
    final db = await DBHelper.database();
    await db.delete('favorite_masjids', where: 'id = ?', whereArgs: [id]);
  }

  static Future<Map<String, bool>> getPrayerLogForDate(String dateKey) async {
    final db = await DBHelper.database();
    final rows = await db.query(
      'prayer_logs',
      where: 'date_key = ?',
      whereArgs: [dateKey],
    );
    return {
      for (final row in rows)
        row['prayer_name'] as String: (row['completed'] as int) == 1,
    };
  }

  static Future<void> setPrayerCompleted({
    required String dateKey,
    required String prayerName,
    required bool completed,
  }) async {
    final db = await DBHelper.database();
    await db.insert('prayer_logs', {
      'date_key': dateKey,
      'prayer_name': prayerName,
      'completed': completed ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>> exportTrackerData() async {
    final db = await DBHelper.database();
    final prayerRows = await db.query('prayer_logs');
    final ramadanRows = await db.query(
      'app_settings',
      where: 'setting_key LIKE ?',
      whereArgs: ['$trackerRamadanKeyPrefix%'],
    );

    final prayerStatusByDate = <String, Map<String, bool>>{};
    for (final row in prayerRows) {
      final dateKey = row['date_key'] as String;
      final prayerName = row['prayer_name'] as String;
      final completed = (row['completed'] as int) == 1;
      final dateMap = prayerStatusByDate.putIfAbsent(
        dateKey,
        () => <String, bool>{},
      );
      dateMap[prayerName] = completed;
    }

    final ramadanStatusByYear = <String, Map<String, String>>{};
    for (final row in ramadanRows) {
      final settingKey = row['setting_key'] as String;
      final year = settingKey.substring(trackerRamadanKeyPrefix.length);
      final settingValue = row['setting_value'] as String;
      try {
        final parsed =
            (settingValue.isEmpty
                    ? <String, dynamic>{}
                    : Map<String, dynamic>.from(
                        (settingValue.startsWith('{')
                            ? (jsonDecode(settingValue) as Map<String, dynamic>)
                            : <String, dynamic>{}),
                      ))
                .map((k, v) => MapEntry(k, v?.toString() ?? ''));
        ramadanStatusByYear[year] = parsed;
      } catch (_) {
        ramadanStatusByYear[year] = <String, String>{};
      }
    }

    return {
      'type': 'athan_tracker_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'prayerStatusByDate': prayerStatusByDate,
      'ramadanStatusByYear': ramadanStatusByYear,
    };
  }

  static Future<void> importTrackerData(
    Map<String, dynamic> payload, {
    bool replaceExisting = true,
  }) async {
    final db = await DBHelper.database();

    final prayerStatusByDate =
        (payload['prayerStatusByDate'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final ramadanStatusByYear =
        (payload['ramadanStatusByYear'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    await db.transaction((txn) async {
      if (replaceExisting) {
        await txn.delete('prayer_logs');
        await txn.delete(
          'app_settings',
          where: 'setting_key LIKE ?',
          whereArgs: ['$trackerRamadanKeyPrefix%'],
        );
      }

      for (final dateEntry in prayerStatusByDate.entries) {
        final dateKey = dateEntry.key;
        final prayers =
            (dateEntry.value as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};

        for (final prayerEntry in prayers.entries) {
          await txn.insert('prayer_logs', {
            'date_key': dateKey,
            'prayer_name': prayerEntry.key,
            'completed': prayerEntry.value == true ? 1 : 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      for (final yearEntry in ramadanStatusByYear.entries) {
        final year = yearEntry.key;
        final statuses =
            (yearEntry.value as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final normalized = statuses.map(
          (k, v) => MapEntry(k, v?.toString() ?? ''),
        );

        await txn.insert('app_settings', {
          'setting_key': '$trackerRamadanKeyPrefix$year',
          'setting_value': jsonEncode(normalized),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<String?> getSetting(String key) async {
    final db = await DBHelper.database();
    final rows = await db.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['setting_value'] as String;
  }

  static Future<void> setSetting(String key, String value) async {
    final db = await DBHelper.database();
    await db.insert('app_settings', {
      'setting_key': key,
      'setting_value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Pinned (My) Masjid
  // ──────────────────────────────────────────────────────────────────────────

  static const _kPinnedId = 'pinned_masjid_id';
  static const _kPinnedName = 'pinned_masjid_name';
  static const _kPinnedAddress = 'pinned_masjid_address';
  static const _kPinnedLat = 'pinned_masjid_lat';
  static const _kPinnedLng = 'pinned_masjid_lng';

  /// Returns a map with keys {id, name, address, lat, lng}, or null if none pinned.
  static Future<Map<String, dynamic>?> getPinnedMasjid() async {
    final id = await getSetting(_kPinnedId);
    if (id == null) return null;
    final name = await getSetting(_kPinnedName);
    final address = await getSetting(_kPinnedAddress);
    final lat = double.tryParse(await getSetting(_kPinnedLat) ?? '');
    final lng = double.tryParse(await getSetting(_kPinnedLng) ?? '');
    if (name == null || lat == null || lng == null) return null;
    return {
      'id': id,
      'name': name,
      'address': address ?? '',
      'lat': lat,
      'lng': lng,
    };
  }

  static Future<void> setPinnedMasjid({
    required String id,
    required String name,
    required String address,
    required double lat,
    required double lng,
  }) async {
    final db = await database();
    await db.transaction((txn) async {
      for (final e in <String, String>{
        _kPinnedId: id,
        _kPinnedName: name,
        _kPinnedAddress: address,
        _kPinnedLat: lat.toString(),
        _kPinnedLng: lng.toString(),
      }.entries) {
        await txn.insert('app_settings', {
          'setting_key': e.key,
          'setting_value': e.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    pinnedChangeNotifier.notifyListeners();
  }

  static Future<void> clearPinnedMasjid() async {
    final db = await database();
    await db.delete(
      'app_settings',
      where: 'setting_key IN (?, ?, ?, ?, ?)',
      whereArgs: [
        _kPinnedId,
        _kPinnedName,
        _kPinnedAddress,
        _kPinnedLat,
        _kPinnedLng,
      ],
    );
    pinnedChangeNotifier.notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Iqamah Offsets
  // ──────────────────────────────────────────────────────────────────────────

  static const _kIqFajr = 'iqamah_fajr';
  static const _kIqDhuhr = 'iqamah_dhuhr';
  static const _kIqAsr = 'iqamah_asr';
  static const _kIqMaghrib = 'iqamah_maghrib';
  static const _kIqIsha = 'iqamah_isha';
  static const _kJumaa1 = 'jumaa_time_1';
  static const _kJumaa2 = 'jumaa_time_2';
  static const kAlertMode = 'settings_alert_mode';

  /// Returns iqamah settings with defaults matching Masjid Al-Salam:
  /// fajr=30, dhuhr=15, asr=15, maghrib=10, isha=15.
  static Future<Map<String, dynamic>> getIqamahSettings() async {
    return {
      'fajr': int.tryParse(await getSetting(_kIqFajr) ?? '') ?? 30,
      'dhuhr': int.tryParse(await getSetting(_kIqDhuhr) ?? '') ?? 15,
      'asr': int.tryParse(await getSetting(_kIqAsr) ?? '') ?? 15,
      'maghrib': int.tryParse(await getSetting(_kIqMaghrib) ?? '') ?? 10,
      'isha': int.tryParse(await getSetting(_kIqIsha) ?? '') ?? 15,
      'jumaa1': await getSetting(_kJumaa1) ?? '13:45',
      'jumaa2': await getSetting(_kJumaa2) ?? '15:15',
    };
  }

  static Future<void> deleteAllData() async {
    final db = await database();
    await db.delete('app_settings');
    await db.delete('prayer_logs');
    await db.delete('favorite_masjids');
  }

  static Future<void> setIqamahSettings(Map<String, dynamic> s) async {
    final db = await database();
    await db.transaction((txn) async {
      for (final e in <String, String>{
        _kIqFajr: s['fajr'].toString(),
        _kIqDhuhr: s['dhuhr'].toString(),
        _kIqAsr: s['asr'].toString(),
        _kIqMaghrib: s['maghrib'].toString(),
        _kIqIsha: s['isha'].toString(),
        _kJumaa1: s['jumaa1'] as String,
        _kJumaa2: s['jumaa2'] as String,
      }.entries) {
        await txn.insert('app_settings', {
          'setting_key': e.key,
          'setting_value': e.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
