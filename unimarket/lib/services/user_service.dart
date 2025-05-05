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

  // Get current user profile details (with improved local fallback)
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      print('UserService: Getting current user profile');
      
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }
      
      // First check local database with timeout to prevent waiting too long
      UserModel? localUser = await Future.value(_sqliteUserDAO.getCurrentUser())
          .timeout(const Duration(seconds: 2), onTimeout: () {
        print('UserService: Local database lookup timed out');
        return null;
      });
      
      // If we have a local user, use it immediately (offline first approach)
      if (localUser != null) {
        print('UserService: Retrieved user from local database: ${localUser.displayName}');
        
        // Then try to refresh from server in background if online
        _refreshUserFromServer(localUser.id).then((updated) {
          print('UserService: Background sync completed');
        }).catchError((e) {
          print('UserService: Background sync error: $e');
        });
        
        return localUser;
      }
      
      // If online but no local user, try to get from Firebase
      if (await _connectivityService.checkConnectivity()) {
        print('UserService: No local user, fetching from Firebase');
        
        final firebaseUser = await _firebaseDAO.getCurrentUserDetails()
            .timeout(const Duration(seconds: 5), onTimeout: () {
          print('UserService: Firebase fetch timed out');
          return null;
        });
        
        if (firebaseUser != null) {
          // Update local database
          await _sqliteUserDAO.saveUser(firebaseUser, isCurrentUser: true);
          print('UserService: Saved Firebase user to local database');
          return firebaseUser;
        }
      }
      
      // If we got here, we couldn't get the user from either source
      // Create a fallback user from Firebase Auth as last resort
      final authUser = _firebaseDAO.getCurrentUser();
      if (authUser != null) {
        print('UserService: Creating fallback user from Firebase Auth');
        final fallbackUser = UserModel(
          id: authUser.uid,
          displayName: authUser.displayName ?? "User",
          email: authUser.email ?? "user@example.com",
          photoURL: authUser.photoURL,
        );
        
        // Save this fallback user to local database
        await _sqliteUserDAO.saveUser(fallbackUser, isCurrentUser: true);
        return fallbackUser;
      }
      
      return null;
    } catch (e) {
      print("UserService: Error getting current user profile: $e");
      return null;
    }
  }

  // Helper method to refresh user from server in background
  Future<bool> _refreshUserFromServer(String userId) async {
    try {
      if (await _connectivityService.checkConnectivity()) {
        final firebaseUser = await _firebaseDAO.getUserById(userId)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        
        if (firebaseUser != null) {
          // Update local database
          await _sqliteUserDAO.saveUser(firebaseUser, 
              isCurrentUser: _firebaseDAO.getCurrentUserId() == userId);
          return true;
        }
      }
      return false;
    } catch (e) {
      print("UserService: Error refreshing user from server: $e");
      return false;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> userData) async {
    final userId = _firebaseDAO.getCurrentUserId();
    if (userId == null) {
      return false;
    }
    
    try {
      // First update in Firebase if online
      bool success = false;
      if (await _connectivityService.checkConnectivity()) {
        success = await _firebaseDAO.updateUserProfile(userId, userData);
      }
      
      // Get the current user from local database
      UserModel? currentUser = await _sqliteUserDAO.getUserById(userId);
      
      if (currentUser != null) {
        // Update the local model with new data
        final Map<String, dynamic> updatedData = {...currentUser.toMap(), ...userData};
        final updatedUser = UserModel.fromMap(updatedData);
        
        // Save to local database
        await _sqliteUserDAO.saveUser(updatedUser, isCurrentUser: true);
        success = true;
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
      if (await _connectivityService.checkConnectivity()) {
        final ref = _storage.ref().child('profile_images').child('$userId.jpg');
        final uploadTask = ref.putFile(imageFile);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // Update user profile with new photo URL
        await _firebaseDAO.updateUserProfile(userId, {'photoURL': downloadUrl});
        
        // Also update in local database
        final currentUser = await _sqliteUserDAO.getCurrentUser();
        if (currentUser != null) {
          final updatedUser = UserModel(
            id: currentUser.id,
            displayName: currentUser.displayName,
            email: currentUser.email,
            photoURL: downloadUrl,
            bio: currentUser.bio,
            ratingAverage: currentUser.ratingAverage,
            reviewsCount: currentUser.reviewsCount,
            createdAt: currentUser.createdAt,
            updatedAt: currentUser.updatedAt,
            major: currentUser.major,
          );
          await _sqliteUserDAO.saveUser(updatedUser, isCurrentUser: true);
        }

        return downloadUrl;
      } else {
        throw Exception("Cannot upload profile picture while offline");
      }
    } catch (e) {
      print("UserService: Error uploading profile picture: $e");
      return null;
    }
  }

  // Get user by ID (with improved local fallback)
  Future<UserModel?> getUserById(String userId) async {
    try {
      print('UserService: Getting user by ID: $userId');
      
      // Check if this is the current user, if so use getCurrentUserProfile
      if (userId == _firebaseDAO.getCurrentUserId()) {
        return await getCurrentUserProfile();
      }
      
      // First try to get from local database
      UserModel? user = await _sqliteUserDAO.getUserById(userId);
      
      if (user != null) {
        print('UserService: Found user in local database: ${user.displayName}');
        
        // Try to refresh in background if online
        _refreshUserFromServer(userId).then((updated) {
          if (updated) {
            print('UserService: User updated from server in background');
          }
        });
        
        return user;
      }
      
      // If not found locally and online, try to get from Firebase
      if (await _connectivityService.checkConnectivity()) {
        print('UserService: User not found locally, fetching from Firebase');
        
        final firebaseUser = await _firebaseDAO.getUserById(userId)
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        
        if (firebaseUser != null) {
          // Save to local database
          await _sqliteUserDAO.saveUser(firebaseUser);
          print('UserService: Saved Firebase user to local database');
          return firebaseUser;
        }
      }
      
      // If we still don't have a user, create a minimal placeholder
      print('UserService: Creating minimal placeholder user');
      return UserModel(
        id: userId,
        displayName: 'User',
        email: '',
      );
    } catch (e) {
      print("UserService: Error getting user by ID: $e");
      
      // Create a minimal placeholder user on error
      return UserModel(
        id: userId,
        displayName: 'User',
        email: '',
      );
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

  // Add to wishlist (keep original methods)
  Future<bool> addToWishlist(String productId) async {
    return await _firebaseDAO.addToWishlist(productId);
  }

  // Remove from wishlist (keep original methods)
  Future<bool> removeFromWishlist(String productId) async {
    return await _firebaseDAO.removeFromWishlist(productId);
  }

  // Check if product is in wishlist (keep original methods)
  Future<bool> isProductInWishlist(String productId) async {
    return await _firebaseDAO.isProductInWishlist(productId);
  }

  // Keep original product methods
  Future<List<ProductModel>> getProductsFromUser(String userId) async {
    final productMaps = await _firebaseDAO.getProductsByUserId(userId);
    return productMaps.map((map) => ProductModel.fromMap(map, docId: map['id'])).toList();
  }
  
  // Keep original wishlist methods
  Future<List<ProductModel>> getWishlistProducts() async {
    final products = await _firebaseDAO.getWishlistProducts();
    return products.map((product) => ProductModel.fromMap(product, docId: product['id'])).toList();
  }
  
  // Preload user data for faster access
  Future<void> preloadUserData(List<String> userIds) async {
    if (userIds.isEmpty) return;
    
    print('UserService: Preloading data for ${userIds.length} users');
    
    // First get all available local users
    final localUsers = await _sqliteUserDAO.getAllUsers();
    final localUserIds = localUsers.map((user) => user.id).toSet();
    
    // Filter out users we already have
    final missingUserIds = userIds.where((id) => !localUserIds.contains(id)).toList();
    
    if (missingUserIds.isEmpty) {
      print('UserService: All users already available locally');
      return;
    }
    
    // If online, fetch missing users from Firebase
    if (await _connectivityService.checkConnectivity()) {
      for (final userId in missingUserIds) {
        try {
          final user = await _firebaseDAO.getUserById(userId)
              .timeout(const Duration(seconds: 2), onTimeout: () => null);
              
          if (user != null) {
            await _sqliteUserDAO.saveUser(user);
            print('UserService: Preloaded user ${user.displayName}');
          }
        } catch (e) {
          print('UserService: Error preloading user $userId: $e');
        }
      }
    }
  }
}