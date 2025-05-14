import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<List<Map<String, dynamic>>> getLocalOffers() async {
  final db = await database;
  return await db.query('offers');
}

Future<int> deleteLocalOffer(int id) async {
  final db = await database;
  return await db.delete('offers', where: 'id = ?', whereArgs: [id]);
}

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'offers.db'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE finds (
            id TEXT PRIMARY KEY,
            description TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE offers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            findId TEXT NOT NULL,
            userId INTEGER NOT NULL,
            description TEXT NOT NULL,
            price INTEGER NOT NULL,
            image TEXT,
            FOREIGN KEY (findId) REFERENCES finds (id),
            FOREIGN KEY (userId) REFERENCES users (id)
          )
        ''');
      },
      version: 1,
    );
  }

  Future<int> insertOffer(Map<String, dynamic> offer) async {
    final db = await database;
    return await db.insert('offers', offer);
  }
}