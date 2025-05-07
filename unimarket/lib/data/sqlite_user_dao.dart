import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:unimarket/models/user_model.dart';

class SQLiteUserDAO {
  static final SQLiteUserDAO _instance = SQLiteUserDAO._internal();
  factory SQLiteUserDAO() => _instance;
  SQLiteUserDAO._internal();

  static Database? _database;
  static bool isInitialized = false;
  static bool _isInitializing = false;
  static final Completer<void> _initCompleter = Completer<void>();

  // Database name and version
  static const String _dbName = 'unimarket_users.db';
  static const int _dbVersion = 5; // Incrementado para forzar reconstrucción

  // Table names
  static const String tableUsers = 'users';
  static const String tableOrderInfo = 'orderInfo';


  // Get database instance with robust error handling
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    // Si ya está en proceso de inicialización, espera a que termine
    if (_isInitializing) {
      try {
        await _initCompleter.future.timeout(Duration(seconds: 5), 
          onTimeout: () => throw TimeoutException('Database initialization timed out'));
        
        if (_database != null) return _database!;
        // Si después de esperar aún no hay base de datos, continúa con inicialización
      } catch (e) {
        print('SQLiteUserDAO: Timeout waiting for database initialization: $e');
        // Continúa con la inicialización
      }
    }
    
    return await _initDatabase();
  }

  // Initialize database with timeout and robust error handling
  Future<Database> _initDatabase() async {
    _isInitializing = true;
    
    try {
      print('SQLiteUserDAO: Initializing database...');
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _dbName);
      
      // Check if database exists
      bool databaseExists = await File(path).exists();
      
      // If database exists but might be corrupted, try to delete it first
      if (databaseExists) {
        try {
          // Try to open it first to see if it's corrupted
          final testDb = await openDatabase(path, readOnly: true);
          await testDb.close();
        } catch (e) {
          print('SQLiteUserDAO: Database might be corrupted, deleting: $e');
          try {
            await deleteDatabase(path);
            databaseExists = false;
          } catch (deleteError) {
            print('SQLiteUserDAO: Error deleting corrupted database: $deleteError');
          }
        }
      }
      
      // Open the database with robust error handling
      final db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: onDatabaseDowngradeDelete, // Forzar recreación si hay downgrade
        onOpen: (db) {
          print('SQLiteUserDAO: Database opened successfully');
        },
      ).timeout(Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('Database opening timed out');
      });
      
      _database = db;
      isInitialized = true;
      
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      
      _isInitializing = false;
      print('SQLiteUserDAO: Database initialized successfully');
      return db;
    } catch (e) {
      _isInitializing = false;
      print('SQLiteUserDAO: Error initializing database: $e');
      
      // Complete the completer with an error so waiting futures don't hang
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
      
      // Intenta una recuperación de emergencia con una base de datos en memoria
      try {
        print('SQLiteUserDAO: Attempting emergency in-memory database recovery');
        final recoveryDb = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE $tableUsers(
              id TEXT PRIMARY KEY,
              displayName TEXT NOT NULL,
              email TEXT NOT NULL,
              photoURL TEXT,
              bio TEXT,
              isCurrentUser INTEGER DEFAULT 0
            )
            ''');
          }
        );
        
        _database = recoveryDb;
        isInitialized = true;
        print('SQLiteUserDAO: Emergency database created in memory');
        return recoveryDb;
      } catch (recoveryError) {
        print('SQLiteUserDAO: Emergency recovery failed: $recoveryError');
        rethrow;
      }
    }
  }
  Future<void> _createOrderInfoTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableOrderInfo (
      orderId TEXT PRIMARY KEY,
      hashConfirm TEXT NOT NULL
    )
  ''');
}


  // Create database tables with proper schema
  Future<void> _onCreate(Database db, int version) async {
    print('SQLiteUserDAO: Creating tables for version $version');
    
    await db.execute('''
    CREATE TABLE $tableUsers(
      id TEXT PRIMARY KEY,
      displayName TEXT NOT NULL,
      email TEXT NOT NULL,
      photoURL TEXT,
      profilePicture TEXT,
      bio TEXT,
      ratingAverage REAL,
      reviewsCount INTEGER,
      createdAt TEXT,
      updatedAt TEXT,
      major TEXT,
      isCurrentUser INTEGER DEFAULT 0,
      lastSyncTime INTEGER
    )
    ''');
    
    print('SQLiteUserDAO: Tables created successfully');
    await _createOrderInfoTable(db);
    print('SQLiteUserDAO: ORDER INFO Table created successfully');
  }

  // Handle database upgrades with clean rebuild if needed
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('SQLiteUserDAO: Upgrading database from $oldVersion to $newVersion');
    
    try {
      // Clean rebuild approach for simplicity and reliability
      await db.execute('DROP TABLE IF EXISTS $tableUsers');
      await _onCreate(db, newVersion);
      print('SQLiteUserDAO: Database tables rebuilt for version $newVersion');
    } catch (e) {
      print('SQLiteUserDAO: Error during database upgrade: $e');
      // Continue despite error, let the app attempt to use what's available
    }
  }

  // Initialize the database with forced timeout
  Future<void> initialize() async {
    if (isInitialized) {
      print('SQLiteUserDAO: Already initialized');
      return;
    }

    try {
      // Use timeout to prevent hanging
      await database.timeout(Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('Database initialization timed out');
      });
      
      isInitialized = true;
      print('SQLiteUserDAO: Initialization complete');
    } catch (e) {
      print('SQLiteUserDAO: Error during initialization: $e');
      
      // Force reset database file if initialization fails
      try {
        print('SQLiteUserDAO: Attempting to reset database');
        final databasesPath = await getDatabasesPath();
        final path = join(databasesPath, _dbName);
        
        if (await File(path).exists()) {
          await deleteDatabase(path);
          print('SQLiteUserDAO: Database file deleted for reset');
        }
        
        // Try to initialize again after reset
        _database = null;
        isInitialized = false;
        
        // Don't await here to avoid potential deadlock
        Future.delayed(Duration(milliseconds: 500), () async {
          try {
            await _initDatabase();
            print('SQLiteUserDAO: Database reinitialized after reset');
          } catch (reinitError) {
            print('SQLiteUserDAO: Reinitialization failed: $reinitError');
          }
        });
      } catch (resetError) {
        print('SQLiteUserDAO: Database reset failed: $resetError');
      }
    }
  }

  // Save user to database with simplified error handling and default values
  Future<bool> saveUser(UserModel user, {bool isCurrentUser = false}) async {
    try {
      // Get database connection with timeout
      final db = await database.timeout(Duration(seconds: 3), 
        onTimeout: () => throw TimeoutException('Database connection timed out'));
      
      // First, unset any existing current user if this is a new current user
      if (isCurrentUser) {
        try {
          await db.update(
            tableUsers,
            {'isCurrentUser': 0},
            where: 'isCurrentUser = ?',
            whereArgs: [1],
          );
        } catch (e) {
          print('SQLiteUserDAO: Error unsetting previous current user: $e');
          // Continue despite error
        }
      }
      
      // Get the user's data as a map with safe defaults
      Map<String, dynamic> userData = {
        'id': user.id,
        'displayName': user.displayName.isNotEmpty ? user.displayName : 'User',
        'email': user.email.isNotEmpty ? user.email : 'user@example.com',
        'bio': user.bio ?? '',
        'ratingAverage': user.ratingAverage ?? 0.0,
        'reviewsCount': user.reviewsCount ?? 0,
        'major': user.major ?? '',
        'isCurrentUser': isCurrentUser ? 1 : 0,
        'lastSyncTime': DateTime.now().millisecondsSinceEpoch
      };
      
      // Handle photo URLs safely
      if (user.photoURL != null && user.photoURL!.isNotEmpty) {
        userData['photoURL'] = user.photoURL;
        userData['profilePicture'] = user.photoURL; // Store in both fields
      }
      
      // Handle dates safely
      if (user.createdAt != null) {
        userData['createdAt'] = user.createdAt!.toIso8601String();
      }
      
      if (user.updatedAt != null) {
        userData['updatedAt'] = user.updatedAt!.toIso8601String();
      }
      
      // Use simplified insert or update with conflicts handled
      await db.insert(
        tableUsers,
        userData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('SQLiteUserDAO: User ${user.id} saved successfully');
      return true;
    } catch (e) {
      print('SQLiteUserDAO: Error saving user: $e');
      return false;
    }
  }

  // Get user by id with simplified error handling
  Future<UserModel?> getUserById(String userId) async {
    if (userId.isEmpty) {
      print('SQLiteUserDAO: Cannot get user with empty ID');
      return null;
    }
    
    try {
      final db = await database.timeout(Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Database connection timed out'));
      
      final List<Map<String, dynamic>> users = await db.query(
        tableUsers,
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (users.isEmpty) {
        print('SQLiteUserDAO: User $userId not found');
        return null;
      }
      
      return _convertToUserModel(users.first);
    } catch (e) {
      print('SQLiteUserDAO: Error getting user by ID: $e');
      return null;
    }
  }

  // Get current user with simplified error handling
  Future<UserModel?> getCurrentUser() async {
    try {
      final db = await database.timeout(Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Database connection timed out'));
      
      final List<Map<String, dynamic>> users = await db.query(
        tableUsers,
        where: 'isCurrentUser = ?',
        whereArgs: [1],
        limit: 1,
      );
      
      if (users.isEmpty) {
        print('SQLiteUserDAO: Current user not found');
        return null;
      }
      
      return _convertToUserModel(users.first);
    } catch (e) {
      print('SQLiteUserDAO: Error getting current user: $e');
      return null;
    }
  }

  // Convert SQLite map to UserModel with robust parsing
  UserModel _convertToUserModel(Map<String, dynamic> map) {
    // Safely parse dates
    DateTime? createdAt;
    DateTime? updatedAt;
    
    try {
      final createdAtStr = map['createdAt'];
      if (createdAtStr != null && createdAtStr.toString().isNotEmpty) {
        createdAt = DateTime.parse(createdAtStr.toString());
      }
    } catch (e) {
      print('SQLiteUserDAO: Error parsing createdAt date: $e');
    }
    
    try {
      final updatedAtStr = map['updatedAt'];
      if (updatedAtStr != null && updatedAtStr.toString().isNotEmpty) {
        updatedAt = DateTime.parse(updatedAtStr.toString());
      }
    } catch (e) {
      print('SQLiteUserDAO: Error parsing updatedAt date: $e');
    }
    
    // Safely handle profile picture fields
    String? photoURL;
    try {
      photoURL = map['photoURL']?.toString();
      if ((photoURL == null || photoURL.isEmpty) && map['profilePicture'] != null) {
        photoURL = map['profilePicture']?.toString();
      }
    } catch (e) {
      print('SQLiteUserDAO: Error handling photo URLs: $e');
    }
    
    // Safely parse numeric values
    double? ratingAverage;
    try {
      final rating = map['ratingAverage'];
      if (rating != null) {
        ratingAverage = rating is double ? rating : double.tryParse(rating.toString()) ?? 0.0;
      }
    } catch (e) {
      print('SQLiteUserDAO: Error parsing rating: $e');
    }
    
    int? reviewsCount;
    try {
      final reviews = map['reviewsCount'];
      if (reviews != null) {
        reviewsCount = reviews is int ? reviews : int.tryParse(reviews.toString()) ?? 0;
      }
    } catch (e) {
      print('SQLiteUserDAO: Error parsing reviews count: $e');
    }
    
    // Create user model with safe defaults
    return UserModel(
      id: map['id']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? 'User',
      email: map['email']?.toString() ?? 'user@example.com',
      photoURL: photoURL,
      bio: map['bio']?.toString(),
      ratingAverage: ratingAverage,
      reviewsCount: reviewsCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      major: map['major']?.toString(),
    );
  }

  // Estos métodos deben agregarse a la clase SQLiteUserDAO que te proporcioné antes

  // Get all users in database with limit option
  Future<List<UserModel>> getAllUsers({int limit = 100}) async {
    try {
      final db = await database.timeout(Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Database connection timed out'));
      
      final List<Map<String, dynamic>> userMaps = await db.query(
        tableUsers,
        orderBy: 'displayName ASC',
        limit: limit,
      );
      
      print('SQLiteUserDAO: Retrieved ${userMaps.length} users');
      
      return userMaps.map((userMap) => _convertToUserModel(userMap)).toList();
    } catch (e) {
      print('SQLiteUserDAO: Error getting all users: $e');
      return [];
    }
  }

  // Get user count with timeout
  Future<int> getUserCount() async {
    try {
      final db = await database.timeout(Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Database connection timed out'));
        
      final result = await db.rawQuery('SELECT COUNT(*) FROM $tableUsers');
      final count = Sqflite.firstIntValue(result) ?? 0;
      
      print('SQLiteUserDAO: User count: $count');
      return count;
    } catch (e) {
      print('SQLiteUserDAO: Error getting user count: $e');
      return 0;
    }
  }

  // Flush all data and reset the database (emergency recovery)
  Future<bool> resetDatabase() async {
    try {
      print('SQLiteUserDAO: Performing emergency database reset');
      
      // Close database first
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Get database path and delete file
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _dbName);
      
      if (await File(path).exists()) {
        await deleteDatabase(path);
        print('SQLiteUserDAO: Database file deleted');
      }
      
      // Reset state
      isInitialized = false;
      
      // Reinitialize
      await _initDatabase();
      
      return true;
    } catch (e) {
      print('SQLiteUserDAO: Error during database reset: $e');
      return false;
    }
  }

  //cOSAS PARA EL QR DE ORDERS

  //Método para guardar una unica orden
  Future<void> saveOrderInfo(String orderId, String hashConfirm) async {
    try {
      final db = await database;
      await db.insert(
        tableOrderInfo,
        {
          'orderId': orderId,
          'hashConfirm': hashConfirm,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('SQLiteUserDAO: Saved orderInfo $orderId');
    } catch (e) {
      print('SQLiteUserDAO: Error saving orderInfo: $e');
    }
  }

  //manda a guardar todas las ordenes fetched cuando tenía internet
  Future<void> saveOrderInfoMap(Map<String, String> orderMap) async {
    for (final entry in orderMap.entries) {
      await saveOrderInfo(entry.key, entry.value);
    }
  }

  // EC strategy: obtiene el hashmap en caso de que no haya internet
  Future<Map<String, String>> getAllOrderInfo() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> rows = await db.query(tableOrderInfo);
      return {
        for (var row in rows)
          row['orderId'].toString(): row['hashConfirm'].toString(),
      };
    } catch (e) {
      print('SQLiteUserDAO: Error retrieving orderInfo: $e');
      return {};
    }
  }



}