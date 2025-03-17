import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/models/user_model.dart';

class FirebaseDAO {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<AUTH OPERATIONS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Future<bool> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      print("Login successful");
      return true; 
    } catch (e) {
      print("Login failed: $e");
      return false;
    }
  }


//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<GET OPERATIONS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  User? getCurrentUser() {
    return _auth.currentUser;
  }
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('Product').get();
      return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print("Error getting products: $e");
      return [];
    }
  }
  Future<Map<String, Map<String, dynamic>>> getProductsForCurrentSELLER() async {
    final userId = getCurrentUserId();
    if (userId == null) {
      print("No user is currently logged in.");
      return {};
    }

    try {
      // Encontrar todas las ordenes del usuario actual
      print("user ID: $userId");
      final ordersQuery = await _firestore
        .collection('orders')
        .where('sellerID', isEqualTo: userId)
        .where('status', isEqualTo: 'Purchased')
        .get();

      if (ordersQuery.docs.isEmpty) {
        print("No orders found for the current user.");
        return {};
      }

      // listas de productos y de sus respectivos hashConfirms
      final productIDs = ordersQuery.docs
          .map((doc) => doc['productID'] as String)
          .toList();

      final hashConfirms = ordersQuery.docs
          .map((doc) => doc['hashConfirm'] as String)
          .toList();

      // conseguir el objeto completo del Producto
      final productsQuery = await _firestore
          .collection('Product')
          .where(FieldPath.documentId, whereIn: productIDs)
          .get();

      '''
      Mapa final, cada llave es el ID de un producto y tiene un mapa dentro con 2 llaves:
      1. product: contiene la información del producto
      2. hashConfirm: String del hash necesario
      ''';
      final Map<String, Map<String, dynamic>> productMap = {};

      for (var i = 0; i < productsQuery.docs.length; i++) {
        final productDoc = productsQuery.docs[i];
        final productData = productDoc.data();
        final productId = productDoc.id;

        // Add the product data and its corresponding hashConfirm to the map
        productMap[productId] = {
          'product': productData,
          'hashConfirm': hashConfirms[i],
        };
      }

      return productMap;
    } catch (e) {
      print("Error fetching products for current user: $e");
      return {};
    }
  }




  Future<Map<String, String>> getProductsForCurrentBUYER() async {
    final userId = getCurrentUserId();
    if (userId == null) {
      print("No user is currently logged in.");
      return {};
    }

    try {
      // Encontrar todas las ordenes del usuario actual
      print("user ID: $userId");
      final ordersQuery = await _firestore
          .collection('orders')
          .where('buyerID', isEqualTo: userId)
          .get();

      if (ordersQuery.docs.isEmpty) {
        print("No orders found for the current user.");
        return {};
      }

      // Crear un mapa donde la llave es el hashConfirm y el valor es el productID
      final Map<String, String> hashToProductMap = {};

      for (final doc in ordersQuery.docs) {
        final hashConfirm = doc['hashConfirm'] as String;
        final productID = doc['productID'] as String;
        print("hashconfirm: $hashConfirm");
        print("producID: $productID");
        // Agregar al mapa
        hashToProductMap[hashConfirm] = productID;
      }

      return hashToProductMap;
    } catch (e) {
      print("Error fetching products for current user: $e");
      return {};
    }
  }



//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<CREATE OPERATIONS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

//... gulp.

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<UPDATE OPERATIONS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
  Future<void> updateOrderStatusDelivered(String orderId, String hashConfirm) async {
  try {
    final orderRef = _firestore.collection('orders').doc(orderId);
    await orderRef.update({
      'status': 'Delivered',
    });
    print("Order $orderId status updated to 'Delivered'.");
  } catch (e) {
    print("Error updating order status using orderId: $e");

    // Debugging in case it fails
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where(
            'hashConfirm', 
            isEqualTo: hashConfirm
          )
          .get();

      if (querySnapshot.docs.isEmpty) {
        print("No order found with hashConfirm: $hashConfirm");
        return;
      }
      final orderDoc = querySnapshot.docs.first;
      await orderDoc.reference.update({
        'status': 'Delivered',
      });
      print("Order with hashConfirm $hashConfirm status updated to 'Delivered'.");
    } catch (e) {
      print("Error updating order status using hashConfirm: $e");
      rethrow; 
    }
  }
}




  Future<void> updateOrderStatusPurchased(String orderId) async {
    try {
      final orderRef = _firestore.collection('orders').doc(orderId);
      await orderRef.update({
        'status': 'Purchased',
      });
      print("Order $orderId status updated to 'Purchased'.");
    } catch (e) {
      print("Error updating order status: $e");
      rethrow; 
    }
  }

  //PRODUCTS

  // Product creation method
Future<String?> createProduct(Map<String, dynamic> productData) async {
  try {
    final docRef = await _firestore.collection('Product').add(productData);
    print("Product created with ID: ${docRef.id}");
    return docRef.id;
  } catch (e) {
    print("Error creating product: $e");
    return null;
  }
}

// Method to upload an image and get URL
// Note: This is a placeholder. You'll need to implement actual image upload using Firebase Storage
Future<String?> uploadProductImage(String filePath) async {
  // Implementation for image upload to Firebase Storage
  // Return the download URL
  // For now, it returns a placeholder
  return null;
}

// Method to get product details by ID
Future<Map<String, dynamic>?> getProductById(String productId) async {
  try {
    final docSnapshot = await _firestore.collection('Product').doc(productId).get();
    if (docSnapshot.exists) {
      Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
      data['id'] = docSnapshot.id;
      return data;
    }
    return null;
  } catch (e) {
    print("Error getting product by ID: $e");
    return null;
  }
}

// Method to update a product
Future<bool> updateProduct(String productId, Map<String, dynamic> productData) async {
  try {
    await _firestore.collection('Product').doc(productId).update(productData);
    print("Product $productId updated successfully");
    return true;
  } catch (e) {
    print("Error updating product: $e");
    return false;
  }
}

// Add this method to your FirebaseDAO class

// Delete a product
Future<bool> deleteProduct(String productId) async {
  try {
    await _firestore.collection('Product').doc(productId).delete();
    print('Product $productId deleted successfully');
    return true;
  } catch (e) {
    print('Error deleting product: $e');
    return false;
  }

}








//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<USER OPERATIONS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// Add these methods to your FirebaseDAO class

// Get user details by ID
Future<UserModel?> getUserById(String userId) async {
  try {
    // Add cache configuration to ensure fresh data
    final docSnapshot = await _firestore
        .collection('User')
        .doc(userId)
        .get(GetOptions(source: Source.server)); // Force server fetch
        
    if (docSnapshot.exists && docSnapshot.data() != null) {
      print("User data fetched successfully: ${docSnapshot.data()}"); // Add logging
      return UserModel.fromFirestore(docSnapshot.data()!, docSnapshot.id);
    } else {
      print("User document does not exist or is empty: $userId");
      return null;
    }
  } catch (e) {
    print("Error getting user by ID ($userId): $e");
    return null;
  }
}

// Get current user details
Future<UserModel?> getCurrentUserDetails() async {
  final userId = getCurrentUserId();
  if (userId == null) {
    return null;
  }
  return getUserById(userId);
}

// Update user profile
Future<bool> updateUserProfile(String userId, Map<String, dynamic> userData) async {
  try {
    await _firestore.collection('User').doc(userId).update(userData);
    print("User profile updated successfully");
    return true;
  } catch (e) {
    print("Error updating user profile: $e");
    return false;
  }
}

// Get products by user ID
Future<List<Map<String, dynamic>>> getProductsByUserId(String userId) async {
  try {
    final querySnapshot = await _firestore
        .collection('Product')
        .where('sellerID', isEqualTo: userId)
        .get();
    
    List<Map<String, dynamic>> products = [];
    for (var doc in querySnapshot.docs) {
      Map<String, dynamic> data = doc.data();
      data['id'] = doc.id; // Add document ID to the product data
      products.add(data);
    }
    
    return products;
  } catch (e) {
    print("Error getting products by user ID: $e");
    return [];
  }
}

// Get product with seller details
Future<Map<String, dynamic>?> getProductWithSellerDetails(String productId) async {
  try {
    final productSnapshot = await _firestore.collection('Product').doc(productId).get();
    
    if (!productSnapshot.exists) {
      return null;
    }
    
    Map<String, dynamic> productData = productSnapshot.data() as Map<String, dynamic>;
    productData['id'] = productSnapshot.id;
    
    // Get seller details if sellerId exists
    if (productData.containsKey('sellerID')) {
      final sellerID = productData['sellerID'];
      final sellerSnapshot = await _firestore.collection('User').doc(sellerID).get();
      
      if (sellerSnapshot.exists) {
        final sellerData = sellerSnapshot.data() as Map<String, dynamic>;
        productData['seller'] = {
          'id': sellerID,
          'displayName': sellerData['displayName'] ?? 'Unknown Seller',
          'photoURL': sellerData['profilePicture'],
          'rating': sellerData['ratingAverage'] ?? 0.0,
        };
      }
    }
    
    return productData;
  } catch (e) {
    print("Error getting product with seller details: $e");
    return null;
  }
}

// Add product to wishlist
Future<bool> addToWishlist(String productId) async {
  final userId = getCurrentUserId();
  if (userId == null) {
    return false;
  }
  
  try {
    await _firestore.collection('wishlist').add({
      'productID': productId,
      'userID': userId,
      'addedAt': FieldValue.serverTimestamp(),
    });
    return true;
  } catch (e) {
    print("Error adding to wishlist: $e");
    return false;
  }
}

// Remove product from wishlist
Future<bool> removeFromWishlist(String productId) async {
  final userId = getCurrentUserId();
  if (userId == null) {
    return false;
  }
  
  try {
    final querySnapshot = await _firestore
        .collection('wishlist')
        .where('userID', isEqualTo: userId)
        .where('productID', isEqualTo: productId)
        .get();
    
    if (querySnapshot.docs.isEmpty) {
      return false;
    }
    
    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
    
    return true;
  } catch (e) {
    print("Error removing from wishlist: $e");
    return false;
  }
}

// Get user's wishlist
Future<List<String>> getUserWishlist() async {
  final userId = getCurrentUserId();
  if (userId == null) {
    return [];
  }
  
  try {
    final querySnapshot = await _firestore
        .collection('wishlist')
        .where('userID', isEqualTo: userId)
        .get();
    
    return querySnapshot.docs
        .map((doc) => doc['productID'] as String)
        .toList();
  } catch (e) {
    print("Error getting user wishlist: $e");
    return [];
  }
}

// Check if product is in user's wishlist
Future<bool> isProductInWishlist(String productId) async {
  final wishlist = await getUserWishlist();
  return wishlist.contains(productId);
}

//MAJORS
Future<List<Map<String, dynamic>>> getAllMajors() async {
  try {
    final querySnapshot = await _firestore.collection('majors').get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // El ID del major
      return data;
    }).toList();
  } catch (e) {
    print("Error fetching majors: $e");
    return [];
  }
}

Future<List<Map<String, dynamic>>> getClassesForMajor(String majorId) async {
  try {
    // Consulta la subcolección "clases" dentro del documento de major específico
    final querySnapshot = await _firestore
        .collection('majors')
        .doc(majorId)
        .collection('clases')
        .get();
    
    return querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // El ID de la clase
      return data;
    }).toList();
  } catch (e) {
    print("Error fetching classes for major: $e");
    return [];
  }
}


}