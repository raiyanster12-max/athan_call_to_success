import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Future<Database> database() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'athan_app.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE favorite_masjids(id TEXT PRIMARY KEY, name TEXT, address TEXT, lat REAL, lng REAL)',
        );
      },
      version: 1,
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
}