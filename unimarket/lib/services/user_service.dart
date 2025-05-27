// lib/services/user_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/data/sqlite_user_dao.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'dart:io';

class UserService {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final SQLiteUserDAO _sqliteUserDAO = SQLiteUserDAO();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Singleton pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // Cache for frequently accessed users
  final Map<String, UserModel> _userCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 15);

  // Flag to ensure initialization happens once
  bool _isInitialized = false;

  // Initialize
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('UserService: Initializing...');
      await _sqliteUserDAO.initialize();
      await syncCurrentUser();
      _isInitialized = true;
      print('UserService: Initialization complete');
    } catch (e) {
      print('UserService: Error during initialization: $e');
      // Still mark as initialized to prevent repeated attempts
      _isInitialized = true;
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _firebaseDAO.getCurrentUser();
  }

  // Get current user profile details with improved offline-first strategy
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      print('UserService: Getting current user profile');
      
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }
      
      // Get current user ID
      final currentUserId = _firebaseDAO.getCurrentUserId();
      if (currentUserId == null) {
        print('UserService: No current user ID found');
        return null;
      }
      
      // Use the enhanced getUserById method which has better caching
      return await getUserById(currentUserId);
      
    } catch (e) {
      print("UserService: Error getting current user profile: $e");
      return null;
    }
  }

  // Enhanced getUserById with comprehensive offline-first strategy
  Future<UserModel?> getUserById(String userId) async {
    try {
      print('UserService: Getting user by ID: $userId');
      
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }
      
      // Check memory cache first (fastest)
      final cachedUser = _getCachedUser(userId);
      if (cachedUser != null) {
        print('UserService: Using memory cached user: ${cachedUser.displayName}');
        
        // Refresh in background if online and cache is getting old
        _refreshUserInBackground(userId);
        
        return cachedUser;
      }
      
      // Try local database (fast)
      UserModel? user = await _sqliteUserDAO.getUserById(userId)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      
      if (user != null) {
        print('UserService: Found user in local database: ${user.displayName}');
        
        // Add to memory cache
        _cacheUser(userId, user);
        
        // Refresh from server in background if online
        _refreshUserInBackground(userId);
        
        return user;
      }
      
      // Check connectivity before attempting network request
      final hasInternet = await _connectivityService.checkConnectivity();
      if (!hasInternet) {
        print('UserService: Offline - creating fallback user for $userId');
        return _createFallbackUser(userId);
      }
      
      // Try Firebase (slow but comprehensive)
      print('UserService: User not found locally, fetching from Firebase');
      
      final firebaseUser = await _firebaseDAO.getUserById(userId)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      
      if (firebaseUser != null) {
        // Save to local database for future use
        await _sqliteUserDAO.saveUser(firebaseUser, 
            isCurrentUser: _firebaseDAO.getCurrentUserId() == userId);
        
        // Add to memory cache
        _cacheUser(userId, firebaseUser);
        
        print('UserService: Saved Firebase user to local database');
        return firebaseUser;
      }
      
      // If all else fails, create a fallback user
      print('UserService: Creating fallback user for missing user: $userId');
      return _createFallbackUser(userId);
      
    } catch (e) {
      print("UserService: Error getting user by ID: $e");
      
      // Return fallback user on error to prevent UI crashes
      return _createFallbackUser(userId);
    }
  }

  // Check memory cache for user
  UserModel? _getCachedUser(String userId) {
    if (!_userCache.containsKey(userId)) return null;
    
    final cacheTime = _cacheTimestamps[userId];
    if (cacheTime == null) return null;
    
    // Check if cache is still valid
    if (DateTime.now().difference(cacheTime) > _cacheExpiry) {
      _userCache.remove(userId);
      _cacheTimestamps.remove(userId);
      return null;
    }
    
    return _userCache[userId];
  }

  // Add user to memory cache
  void _cacheUser(String userId, UserModel user) {
    _userCache[userId] = user;
    _cacheTimestamps[userId] = DateTime.now();
    
    // Clean old cache entries periodically
    if (_userCache.length > 50) {
      _cleanOldCacheEntries();
    }
  }

  // Clean old cache entries
  void _cleanOldCacheEntries() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _userCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    print('UserService: Cleaned ${keysToRemove.length} old cache entries');
  }

  // Refresh user from server in background
  Future<void> _refreshUserInBackground(String userId) async {
    // Don't await this - let it run in background
    Future.delayed(Duration.zero, () async {
      try {
        final hasInternet = await _connectivityService.checkConnectivity();
        if (!hasInternet) return;
        
        final firebaseUser = await _firebaseDAO.getUserById(userId)
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        
        if (firebaseUser != null) {
          // Update local database
          await _sqliteUserDAO.saveUser(firebaseUser, 
              isCurrentUser: _firebaseDAO.getCurrentUserId() == userId);
          
          // Update memory cache
          _cacheUser(userId, firebaseUser);
          
          print('UserService: Background refresh completed for ${firebaseUser.displayName}');
        }
      } catch (e) {
        print("UserService: Background refresh error for $userId: $e");
      }
    });
  }

  // Create fallback user to prevent UI errors
  UserModel _createFallbackUser(String userId) {
    return UserModel(
      id: userId,
      displayName: 'User',
      email: '',
      bio: '',
      major: '',
      ratingAverage: 0.0,
      reviewsCount: 0,
      createdAt: DateTime.now(),
    );
  }

  // Batch load users for better performance
  Future<List<UserModel>> batchGetUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    
    print('UserService: Batch loading ${userIds.length} users');
    
    final List<UserModel> users = [];
    final List<String> usersToFetchFromNetwork = [];
    
    // First pass: get from cache and local database
    for (final userId in userIds) {
      // Try memory cache first
      final cachedUser = _getCachedUser(userId);
      if (cachedUser != null) {
        users.add(cachedUser);
        continue;
      }
      
      // Try local database
      try {
        final localUser = await _sqliteUserDAO.getUserById(userId)
            .timeout(const Duration(seconds: 1), onTimeout: () => null);
        
        if (localUser != null) {
          users.add(localUser);
          _cacheUser(userId, localUser);
        } else {
          usersToFetchFromNetwork.add(userId);
        }
      } catch (e) {
        usersToFetchFromNetwork.add(userId);
      }
    }
    
    // Second pass: fetch missing users from network if online
    if (usersToFetchFromNetwork.isNotEmpty && 
        await _connectivityService.checkConnectivity()) {
      print('UserService: Fetching ${usersToFetchFromNetwork.length} users from network');
      
      // Fetch users in parallel with reasonable timeout
      final networkFutures = usersToFetchFromNetwork.map((userId) => 
        _firebaseDAO.getUserById(userId)
            .timeout(const Duration(seconds: 2), onTimeout: () => null)
            .then((user) => user != null ? MapEntry(userId, user) : null)
      );
      
      final networkResults = await Future.wait(networkFutures);
      
      for (final result in networkResults) {
        if (result != null) {
          final user = result.value;
          users.add(user);
          
          // Save to local database and cache
          await _sqliteUserDAO.saveUser(user);
          _cacheUser(result.key, user);
        }
      }
    }
    
    // Create fallback users for any missing users
    final foundUserIds = users.map((u) => u.id).toSet();
    for (final userId in userIds) {
      if (!foundUserIds.contains(userId)) {
        users.add(_createFallbackUser(userId));
      }
    }
    
    print('UserService: Batch load completed: ${users.length}/${userIds.length} users');
    return users;
  }

  // Preload user data for faster access (improved version)
  Future<void> preloadUserData(List<String> userIds) async {
    if (userIds.isEmpty) return;
    
    print('UserService: Preloading data for ${userIds.length} users');
    
    // Use batch loading for better performance
    await batchGetUsers(userIds);
  }

  // Update user profile with offline support
  Future<bool> updateUserProfile(Map<String, dynamic> userData) async {
    final userId = _firebaseDAO.getCurrentUserId();
    if (userId == null) {
      return false;
    }
    
    try {
      bool success = false;
      
      // Get current user data
      UserModel? currentUser = await _sqliteUserDAO.getUserById(userId);
      
      if (currentUser != null) {
        // Update the local model with new data
        final Map<String, dynamic> updatedData = {...currentUser.toMap(), ...userData};
        final updatedUser = UserModel.fromMap(updatedData);
        
        // Save to local database first (offline-first)
        await _sqliteUserDAO.saveUser(updatedUser, isCurrentUser: true);
        
        // Update memory cache
        _cacheUser(userId, updatedUser);
        
        success = true;
        print('UserService: Updated user profile locally');
      }
      
      // Try to update in Firebase if online
      if (await _connectivityService.checkConnectivity()) {
        try {
          final firebaseSuccess = await _firebaseDAO.updateUserProfile(userId, userData)
              .timeout(const Duration(seconds: 10));
          
          if (firebaseSuccess) {
            print('UserService: Updated user profile in Firebase');
          }
        } catch (e) {
          print('UserService: Error updating in Firebase (kept local changes): $e');
          // Don't fail here - we have local changes
        }
      }
      
      return success;
    } catch (e) {
      print("UserService: Error updating user profile: $e");
      return false;
    }
  }

  // Upload profile picture with improved offline handling
  Future<String?> uploadProfilePicture(File imageFile) async {
    final userId = _firebaseDAO.getCurrentUserId();
    if (userId == null) {
      return null;
    }

    try {
      // Check if we're online
      if (!(await _connectivityService.checkConnectivity())) {
        throw Exception("Cannot upload profile picture while offline");
      }
      
      final ref = _storage.ref().child('profile_images').child('$userId.jpg');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user profile with new photo URL
      await updateUserProfile({'photoURL': downloadUrl});

      return downloadUrl;
    } catch (e) {
      print("UserService: Error uploading profile picture: $e");
      return null;
    }
  }

  // Sync current user from Firebase to local database
  Future<UserModel?> syncCurrentUser() async {
    try {
      final userId = _firebaseDAO.getCurrentUserId();
      if (userId == null) {
        print("UserService: No user is currently logged in.");
        return null;
      }
      
      // Check if we're online
      if (!(await _connectivityService.checkConnectivity())) {
        print('UserService: Offline, using cached current user');
        return await _sqliteUserDAO.getCurrentUser();
      }
      
      // Get current user from Firebase with timeout
      final currentUser = await _firebaseDAO.getUserById(userId)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
          
      if (currentUser == null) {
        print('UserService: Failed to fetch current user from Firebase');
        return await _sqliteUserDAO.getCurrentUser();
      }
      
      // Save to local database as current user
      await _sqliteUserDAO.saveUser(currentUser, isCurrentUser: true);
      
      // Update memory cache
      _cacheUser(userId, currentUser);
      
      print('UserService: Current user synced from Firebase: ${currentUser.displayName}');
      
      return currentUser;
    } catch (e) {
      print("UserService: Error syncing current user: $e");
      return await _sqliteUserDAO.getCurrentUser();
    }
  }

  // Get all locally stored users
  Future<List<UserModel>> getAllLocalUsers() async {
    return await _sqliteUserDAO.getAllUsers();
  }

  // Clear user cache (for debugging/memory management)
  void clearCache() {
    _userCache.clear();
    _cacheTimestamps.clear();
    print('UserService: Cache cleared');
  }

  // Get cache statistics (for debugging)
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCache': _userCache.length,
      'oldestCacheEntry': _cacheTimestamps.values.isEmpty 
          ? null 
          : _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String(),
      'newestCacheEntry': _cacheTimestamps.values.isEmpty 
          ? null 
          : _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b).toIso8601String(),
    };
  }

  // Keep original product methods
  Future<List<ProductModel>> getProductsFromUser(String userId) async {
    try {
      final productMaps = await _firebaseDAO.getProductsByUserId(userId);
      return productMaps.map((map) => ProductModel.fromMap(map, docId: map['id'])).toList();
    } catch (e) {
      print('UserService: Error getting products from user: $e');
      return [];
    }
  }
  
  // Keep original wishlist methods with better error handling
  Future<List<ProductModel>> getWishlistProducts() async {
    try {
      final products = await _firebaseDAO.getWishlistProducts();
      return products.map((product) => ProductModel.fromMap(product, docId: product['id'])).toList();
    } catch (e) {
      print('UserService: Error getting wishlist products: $e');
      return [];
    }
  }

  // Add to wishlist (keep original methods)
  Future<bool> addToWishlist(String productId) async {
    try {
      return await _firebaseDAO.addToWishlist(productId);
    } catch (e) {
      print('UserService: Error adding to wishlist: $e');
      return false;
    }
  }

  // Remove from wishlist (keep original methods)
  Future<bool> removeFromWishlist(String productId) async {
    try {
      return await _firebaseDAO.removeFromWishlist(productId);
    } catch (e) {
      print('UserService: Error removing from wishlist: $e');
      return false;
    }
  }

  // Check if product is in wishlist (keep original methods)
  Future<bool> isProductInWishlist(String productId) async {
    try {
      return await _firebaseDAO.isProductInWishlist(productId);
    } catch (e) {
      print('UserService: Error checking wishlist status: $e');
      return false;
    }
  }
}