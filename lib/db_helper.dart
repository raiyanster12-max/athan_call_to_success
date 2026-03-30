import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// On native (Android/iOS/desktop) all data goes through SQLite.
/// On web, data is stored in the browser's localStorage via shared_preferences.
class DBHelper {
  // ── SQLite helpers (native only) ─────────────────────────────────────────

  static Database? _db;

  static Future<Database> _nativeDatabase() async {
    _db ??= await _openDatabase();
    return _db!;
  }

  static Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'athan_app.db'),
      onCreate: (db, version) async {
        await _createFavoriteMasjidsTable(db);
        await _createPrayerLogsTable(db);
        await _createSettingsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createPrayerLogsTable(db);
        if (oldVersion < 3) await _createSettingsTable(db);
      },
      version: 3,
    );
  }

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

  // ── Masjids ──────────────────────────────────────────────────────────────

  static Future<void> insertMasjid(Map<String, dynamic> data) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = await getMasjids();
      list.removeWhere((m) => m['id'] == data['id']);
      list.add(data);
      await prefs.setString('favorites_data', jsonEncode(list));
    } else {
      final db = await _nativeDatabase();
      await db.insert(
        'favorite_masjids',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getMasjids() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('favorites_data');
      if (raw == null) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final db = await _nativeDatabase();
    return db.query('favorite_masjids');
  }

  static Future<void> deleteMasjid(String id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = await getMasjids();
      list.removeWhere((m) => m['id'] == id);
      await prefs.setString('favorites_data', jsonEncode(list));
    } else {
      final db = await _nativeDatabase();
      await db.delete('favorite_masjids', where: 'id = ?', whereArgs: [id]);
    }
  }

  // ── Prayer Logs ──────────────────────────────────────────────────────────

  static Future<Map<String, bool>> getPrayerLogForDate(String dateKey) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('prayer_log_$dateKey');
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as int) == 1));
    }
    final db = await _nativeDatabase();
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
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final current = await getPrayerLogForDate(dateKey);
      current[prayerName] = completed;
      await prefs.setString(
        'prayer_log_$dateKey',
        jsonEncode(current.map((k, v) => MapEntry(k, v ? 1 : 0))),
      );
    } else {
      final db = await _nativeDatabase();
      await db.insert(
        'prayer_logs',
        {
          'date_key': dateKey,
          'prayer_name': prayerName,
          'completed': completed ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  static Future<String?> getSetting(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('setting_$key');
    }
    final db = await _nativeDatabase();
    final rows = await db.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['setting_value'] as String;
  }

  static Future<void> setSetting(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('setting_$key', value);
    } else {
      final db = await _nativeDatabase();
      await db.insert(
        'app_settings',
        {'setting_key': key, 'setting_value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
