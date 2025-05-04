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

  // Initialize
  Future<void> initialize() async {
    await _sqliteUserDAO.initialize();
    await syncCurrentUser();
  }

  // Get current user
  User? getCurrentUser() {
    return _firebaseDAO.getCurrentUser();
  }

  // Get current user profile details (with local fallback)
 Future<UserModel?> getCurrentUserProfile() async {
  try {
    // First check local database
    UserModel? localUser = await _sqliteUserDAO.getCurrentUser();
    
    // If online, try to get from Firebase and update local
    if (await _connectivityService.checkConnectivity()) {
      final firebaseUser = await _firebaseDAO.getCurrentUserDetails();
      if (firebaseUser != null) {
        // Update local database
        await _sqliteUserDAO.saveUser(firebaseUser, isCurrentUser: true);
        return firebaseUser;
      }
    }
    
    // If offline or Firebase failed, return local user
    return localUser;
  } catch (e) {
    print("Error getting current user profile: $e");
    return null;
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
      
      // Then get the updated user and save to local database
      final updatedUser = await _firebaseDAO.getUserById(userId);
      if (updatedUser != null) {
        await _sqliteUserDAO.saveUser(updatedUser, isCurrentUser: true);
        success = true;
      }
      
      return success;
    } catch (e) {
      print("Error updating user profile: $e");
      return false;
    }
  }

  // Upload profile picture
  Future<String?> uploadProfilePicture(File imageFile) async {
    final userId = _firebaseDAO.getCurrentUserId();
    if (userId == null) {
      return null;
    }

    try {
      final ref = _storage.ref().child('profile_images').child('$userId.jpg');
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user profile with new photo URL
      await _firebaseDAO.updateUserProfile(userId, {'profilePicture': downloadUrl});
      
      // Also update in local database
      final currentUser = await _firebaseDAO.getUserById(userId);
      if (currentUser != null) {
        await _sqliteUserDAO.saveUser(currentUser, isCurrentUser: true);
      }

      return downloadUrl;
    } catch (e) {
      print("Error uploading profile picture: $e");
      return null;
    }
  }

  // Get user by ID (with local fallback)
  Future<UserModel?> getUserById(String userId) async {
    try {
      // First try to get from local database
      UserModel? user = await _sqliteUserDAO.getUserById(userId);
      
      // If online and not found locally (or local data might be stale), 
      // try to get from Firebase
      if (await _connectivityService.checkConnectivity()) {
        final firebaseUser = await _firebaseDAO.getUserById(userId);
        if (firebaseUser != null) {
          // Save to local database
          await _sqliteUserDAO.saveUser(firebaseUser);
          return firebaseUser;
        }
      }
      
      // Return local user if Firebase didn't return anything
      return user;
    } catch (e) {
      print("Error getting user by ID: $e");
      return null;
    }
  }
  
  // Sync current user from Firebase to local database
  Future<UserModel?> syncCurrentUser() async {
    try {
      final userId = _firebaseDAO.getCurrentUserId();
      if (userId == null) {
        print("No user is currently logged in.");
        return null;
      }
      
      // Check if we're online
      if (!(await _connectivityService.checkConnectivity())) {
        print('UserService: Offline, using cached current user');
        return await _sqliteUserDAO.getCurrentUser();
      }
      
      // Get current user from Firebase
      final currentUser = await _firebaseDAO.getUserById(userId);
      if (currentUser == null) {
        print('UserService: Failed to fetch current user from Firebase');
        return null;
      }
      
      // Save to local database as current user
      await _sqliteUserDAO.saveUser(currentUser, isCurrentUser: true);
      print('UserService: Current user synced from Firebase: ${currentUser.displayName}');
      
      return currentUser;
    } catch (e) {
      print("Error syncing current user: $e");
      return null;
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
}