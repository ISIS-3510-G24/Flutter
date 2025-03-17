// lib/services/user_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'dart:io';

class UserService {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user
  User? getCurrentUser() {
    return _firebaseDAO.getCurrentUser();
  }

  // Get current user profile details
  Future<UserModel?> getCurrentUserProfile() async {
    return await _firebaseDAO.getCurrentUserDetails();
  }

  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> userData) async {
    final userId = _firebaseDAO.getCurrentUserId();
    if (userId == null) {
      return false;
    }
    return await _firebaseDAO.updateUserProfile(userId, userData);
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

      return downloadUrl;
    } catch (e) {
      print("Error uploading profile picture: $e");
      return null;
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    return await _firebaseDAO.getUserById(userId);
  }

  // Add to wishlist
  Future<bool> addToWishlist(String productId) async {
    return await _firebaseDAO.addToWishlist(productId);
  }

  // Remove from wishlist
  Future<bool> removeFromWishlist(String productId) async {
    return await _firebaseDAO.removeFromWishlist(productId);
  }

  // Check if product is in wishlist
  Future<bool> isProductInWishlist(String productId) async {
    return await _firebaseDAO.isProductInWishlist(productId);
  }

  Future<List<ProductModel>> getProductsFromUser(String userId) async {
    final productMaps = await _firebaseDAO.getProductsByUserId(userId);
    return productMaps.map((map) => ProductModel.fromMap(map)).toList();
  }

  // Get user's wishlist products
  Future<List<Map<String, dynamic>>> getWishlistProducts() async {
    final wishlistIds = await _firebaseDAO.getUserWishlist();
    List<Map<String, dynamic>> products = [];
    
    for (var id in wishlistIds) {
      final product = await _firebaseDAO.getProductById(id);
      if (product != null) {
        products.add(product);
      }
    }
    
    return products;
  }

  
}