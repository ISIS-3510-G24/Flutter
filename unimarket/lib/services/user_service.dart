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

 // UserService: Corrigiendo el método getProductsFromUser
Future<List<ProductModel>> getProductsFromUser(String userId) async {
  final productMaps = await _firebaseDAO.getProductsByUserId(userId);
  // Se pasa el docId de forma explícita al factory de ProductModel
  return productMaps.map((map) => ProductModel.fromMap(map, docId: map['id'])).toList();
}


 Future<List<ProductModel>> getWishlistProducts() async {
  final products = await _firebaseDAO.getWishlistProducts();
  return products.map((product) => ProductModel.fromMap(product, docId: product['id'])).toList();
}
   
  
}