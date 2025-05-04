import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:unimarket/models/user_model.dart';

class SQLiteUserDAO {
  static final SQLiteUserDAO _instance = SQLiteUserDAO._internal();
  factory SQLiteUserDAO() => _instance;
  SQLiteUserDAO._internal();

  static Database? _database;
  static bool isInitialized = false;

  // Database name and version
  static const String _dbName = 'unimarket_users.db';
  static const int _dbVersion = 3; // Increased version to force migration

  // Table names
  static const String tableUsers = 'users';

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    try {
      print('SQLiteUserDAO: Initializing database...');
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _dbName);
      
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('SQLiteUserDAO: Error initializing database: $e');
      rethrow;
    }
  }

  // Create database tables with proper column names
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
      isCurrentUser INTEGER DEFAULT 0
    )
    ''');
    
    print('SQLiteUserDAO: Tables created successfully');
  }

  // Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('SQLiteUserDAO: Upgrading database from $oldVersion to $newVersion');
    
    if (oldVersion < 3) {
      // Start with a clean slate to fix any issues
      try {
        await db.execute('DROP TABLE IF EXISTS $tableUsers');
        await _onCreate(db, newVersion);
      } catch (e) {
        print('SQLiteUserDAO: Error during migration: $e');
      }
    }
  }

  // Initialize the database
  Future<void> initialize() async {
    if (isInitialized) {
      print('SQLiteUserDAO: Already initialized');
      return;
    }

    try {
      await database;
      isInitialized = true;
      print('SQLiteUserDAO: Initialization complete');
    } catch (e) {
      print('SQLiteUserDAO: Error during initialization: $e');
      isInitialized = false;
      rethrow;
    }
  }

  // Save user to database (insert or update)
  Future<bool> saveUser(UserModel user, {bool isCurrentUser = false}) async {
    try {
      final db = await database;
      
      // First, unset any existing current user if this is a new current user
      if (isCurrentUser) {
        await db.update(
          tableUsers,
          {'isCurrentUser': 0},
          where: 'isCurrentUser = ?',
          whereArgs: [1],
        );
      }
      
      // Get the user's data as a map
      Map<String, dynamic> userData = {
        'id': user.id,
        'displayName': user.displayName,
        'email': user.email,
        'bio': user.bio ?? '',
        'ratingAverage': user.ratingAverage ?? 0.0,
        'reviewsCount': user.reviewsCount ?? 0,
        'major': user.major ?? '',
        'isCurrentUser': isCurrentUser ? 1 : 0
      };
      
      // Handle both photoURL and profilePicture for compatibility
      if (user.photoURL != null) {
        userData['photoURL'] = user.photoURL;
        userData['profilePicture'] = user.photoURL; // Store in both fields
      }
      
      // Handle dates
      if (user.createdAt != null) {
        userData['createdAt'] = user.createdAt!.toIso8601String();
      }
      
      if (user.updatedAt != null) {
        userData['updatedAt'] = user.updatedAt!.toIso8601String();
      }
      
      // Check if user already exists
      final List<Map<String, dynamic>> existingUsers = await db.query(
        tableUsers,
        where: 'id = ?',
        whereArgs: [user.id],
        limit: 1,
      );
      
      if (existingUsers.isNotEmpty) {
        // Update existing user
        await db.update(
          tableUsers,
          userData,
          where: 'id = ?',
          whereArgs: [user.id],
        );
        print('SQLiteUserDAO: Updated user ${user.id} (${user.displayName})');
      } else {
        // Insert new user
        await db.insert(tableUsers, userData);
        print('SQLiteUserDAO: Inserted user ${user.id} (${user.displayName})');
      }
      
      return true;
    } catch (e) {
      print('SQLiteUserDAO: Error saving user: $e');
      return false;
    }
  }

  // Get user by id
  Future<UserModel?> getUserById(String userId) async {
    try {
      final db = await database;
      
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
      
      print('SQLiteUserDAO: Retrieved user $userId (${users.first['displayName']})');
      return _convertToUserModel(users.first);
    } catch (e) {
      print('SQLiteUserDAO: Error getting user by ID: $e');
      return null;
    }
  }

  // Get current user
  Future<UserModel?> getCurrentUser() async {
    try {
      final db = await database;
      
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
      
      print('SQLiteUserDAO: Retrieved current user: ${users.first['displayName']}');
      return _convertToUserModel(users.first);
    } catch (e) {
      print('SQLiteUserDAO: Error getting current user: $e');
      return null;
    }
  }

  // Get all users in database
  Future<List<UserModel>> getAllUsers() async {
    try {
      final db = await database;
      
      final List<Map<String, dynamic>> userMaps = await db.query(
        tableUsers,
        orderBy: 'displayName ASC',
      );
      
      print('SQLiteUserDAO: Retrieved ${userMaps.length} users');
      
      return userMaps.map((userMap) => _convertToUserModel(userMap)).toList();
    } catch (e) {
      print('SQLiteUserDAO: Error getting all users: $e');
      return [];
    }
  }

  // Convert SQLite map to UserModel
  UserModel _convertToUserModel(Map<String, dynamic> map) {
    DateTime? createdAt;
    DateTime? updatedAt;
    
    try {
      if (map['createdAt'] != null) {
        createdAt = DateTime.parse(map['createdAt']);
      }
      
      if (map['updatedAt'] != null) {
        updatedAt = DateTime.parse(map['updatedAt']);
      }
    } catch (e) {
      print('SQLiteUserDAO: Error parsing dates: $e');
    }
    
    // Handle both photoURL and profilePicture fields
    String? photoURL = map['photoURL'];
    if (photoURL == null && map['profilePicture'] != null) {
      photoURL = map['profilePicture'];
    }
    
    return UserModel(
      id: map['id'],
      displayName: map['displayName'],
      email: map['email'],
      photoURL: photoURL,
      bio: map['bio'],
      ratingAverage: map['ratingAverage'],
      reviewsCount: map['reviewsCount'],
      createdAt: createdAt,
      updatedAt: updatedAt,
      major: map['major'],
    );
  }

  // Delete all users
  Future<void> clearAllUsers() async {
    try {
      final db = await database;
      await db.delete(tableUsers);
      print('SQLiteUserDAO: All users cleared');
    } catch (e) {
      print('SQLiteUserDAO: Error clearing all users: $e');
    }
  }

  // Set a user as the current user
  Future<bool> setCurrentUser(String userId) async {
    try {
      final db = await database;
      
      // First, unset any existing current user
      await db.update(
        tableUsers,
        {'isCurrentUser': 0},
        where: 'isCurrentUser = ?',
        whereArgs: [1],
      );
      
      // Then set the new current user
      final count = await db.update(
        tableUsers,
        {'isCurrentUser': 1},
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      print('SQLiteUserDAO: Set current user to $userId ($count rows affected)');
      return count > 0;
    } catch (e) {
      print('SQLiteUserDAO: Error setting current user: $e');
      return false;
    }
  }

  // Get user count
  Future<int> getUserCount() async {
    try {
      final db = await database;
      return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $tableUsers')) ?? 0;
    } catch (e) {
      print('SQLiteUserDAO: Error getting user count: $e');
      return 0;
    }
  }
}