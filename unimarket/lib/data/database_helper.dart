import 'dart:async'; 
import 'package:path/path.dart'; 
import 'package:sqflite/sqflite.dart'; // SQLite para base de datos local en Flutter

class DatabaseHelper {
  // Singleton para evitar múltiples instancias
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database; // Instancia de la base de datos

  DatabaseHelper._internal(); // Constructor interno privado

  // Getter para obtener la base de datos, inicializándola si no existe
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Obtiene todas las ofertas almacenadas localmente en la tabla 'offers'
  Future<List<Map<String, dynamic>>> getLocalOffers() async {
    final db = await database;
    final offers = await db.query('offers');
    print("Retrieved local offers from database: $offers");
    return offers;
  }

  // Elimina una oferta local por su id
  Future<int> deleteLocalOffer(int id) async {
    final db = await database;
    return await db.delete('offers', where: 'id = ?', whereArgs: [id]);
  }

  // Inicializa la base de datos y crea tablas si no existen
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath(); // Ruta del directorio de bases de datos
    return openDatabase(
      join(dbPath, 'offers.db'), // Nombre y ubicación del archivo
      onCreate: (db, version) async {
        // Crear tabla 'users'
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL
          )
        ''');
        // Crear tabla 'finds'
        await db.execute('''
          CREATE TABLE finds (
            id TEXT PRIMARY KEY,
            description TEXT NOT NULL
          )
        ''');
        // Crear tabla 'offers' con claves foráneas a 'finds' y 'users'
        await db.execute('''
          CREATE TABLE offers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            findId TEXT NOT NULL,
            userId TEXT NOT NULL,
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

  // Inserta una nueva oferta en la tabla 'offers'
  Future<int> insertOffer(Map<String, dynamic> offer) async {
    final db = await database;
    print("Inserting offer into local database: $offer");
    return await db.insert('offers', offer);
  }
}
