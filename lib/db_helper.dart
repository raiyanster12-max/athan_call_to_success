import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
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
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'athan_app.db'),
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
    await db.insert(
      'app_settings',
      {
        'setting_key': key,
        'setting_value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}