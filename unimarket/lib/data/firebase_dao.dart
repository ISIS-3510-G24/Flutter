import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<DELETE OPERATIONS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>