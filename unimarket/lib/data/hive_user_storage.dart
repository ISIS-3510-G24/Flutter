import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:unimarket/models/user_model.dart';

class HiveUserStorage {
  // Box name
  static const String _userBoxName = 'users';
  static bool _isInitialized = false;
  
  // Initialize Hive
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('HiveUserStorage: Already initialized');
      return;
    }
    
    try {
      print('HiveUserStorage: Initializing Hive...');
      await Hive.initFlutter();
      
      // Ensure the box is open
      if (!Hive.isBoxOpen(_userBoxName)) {
        await Hive.openBox(_userBoxName);
        print('HiveUserStorage: Opened $_userBoxName box');
      }
      
      _isInitialized = true;
      print('HiveUserStorage: Initialized storage box successfully');
    } catch (e) {
      print('HiveUserStorage: Error initializing storage box: $e');
      _isInitialized = false;
      rethrow;
    }
  }
  
  // Ensure box is open before using it
  static Future<void> _ensureBoxOpen() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (!Hive.isBoxOpen(_userBoxName)) {
      await Hive.openBox(_userBoxName);
    }
  }
  
  // Get users box
  Future<Box> get _userBox async {
    await _ensureBoxOpen();
    return Hive.box(_userBoxName);
  }
  
  // Save a user to storage
  Future<bool> saveUser(UserModel user) async {
    try {
      print('HiveUserStorage: Saving user ${user.id}');
      
      // Prepare user data for serialization
      final Map<String, dynamic> userData = user.toMap();
      
      // Save user data
      final box = await _userBox;
      await box.put(user.id, jsonEncode(userData));
      
      print('HiveUserStorage: User saved: ${user.id}');
      return true;
    } catch (e) {
      print('HiveUserStorage: Error saving user ${user.id}: $e');
      return false;
    }
  }
  
  // Get a user from storage
  Future<UserModel?> getUser(String userId) async {
    try {
      print('HiveUserStorage: Getting user $userId');
      final box = await _userBox;
      final String? userString = box.get(userId);
      
      if (userString == null) {
        print('HiveUserStorage: User $userId not found');
        return null;
      }
      
      // Parse user data
      try {
        final Map<String, dynamic> userData = jsonDecode(userString);
        print('HiveUserStorage: Retrieved user $userId');
        return UserModel.fromMap(userData);
      } catch (e) {
        print('HiveUserStorage: Error decoding user data: $e');
        return null;
      }
    } catch (e) {
      print('HiveUserStorage: Error getting user $userId: $e');
      return null;
    }
  }
  
  // Check if a user exists in storage
  Future<bool> userExists(String userId) async {
    try {
      final box = await _userBox;
      return box.containsKey(userId);
    } catch (e) {
      print('HiveUserStorage: Error checking if user exists: $e');
      return false;
    }
  }
  
  // Delete a user from storage
  Future<bool> deleteUser(String userId) async {
    try {
      print('HiveUserStorage: Deleting user $userId');
      final box = await _userBox;
      await box.delete(userId);
      print('HiveUserStorage: User $userId deleted');
      return true;
    } catch (e) {
      print('HiveUserStorage: Error deleting user $userId: $e');
      return false;
    }
  }
}