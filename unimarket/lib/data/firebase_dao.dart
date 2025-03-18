import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/models/order_model.dart';


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

Future<bool> createUser(String email, String password, String bio, String major, String displayName )async {
    try {
      
       UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      String uid = userCredential.user!.uid;
      await _firestore.collection("User").doc(uid).set({
      "email": email,
      "displayName": displayName,
      "bio": bio,
      "major": major,
      "profilePicture": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Default_pfp.svg/2048px-Default_pfp.svg.png",
      "ratingAverage": 0,
      "reviewsCount": 0,
      "updatedAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(),  
    });

    await _firestore.collection("User").doc(uid).collection("wishlist").doc("placeholder").set({
      "message": "Placeholder wishlist",
    });

    await _firestore.collection("User").doc(uid).collection("reviews").doc("placeholder").set({
      "message": "Placeholder review",
    });
      print("User creation successful");
      return true; 
    } catch (e) {
      print("User creation failed: $e");
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


  Future<List<String>> fetchMajors() async {
  try {
    final querySnapshot = await _firestore.collection('majors').get();
    return querySnapshot.docs.map((doc) => doc.id).toList();
  } catch (e) {
    print("Error fetching majors: $e");
    return [];
  }
}

  Future<OrderModel?> getOrderById(String orderId) async {
      try {
        final doc = await _firestore.collection('orders').doc(orderId).get();
        if (doc.exists) {
          return OrderModel.fromFirestore(doc.data()!, doc.id);
        }
        return null;
      } catch (e) {
        print("Error getting order by ID: $e");
        return null;
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
Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final orderRef = _firestore.collection('orders').doc(orderId);
      await orderRef.update({
        'status': status,
      });
      print("Order $orderId status updated to '$status'.");
    } catch (e) {
      print("Error updating order status: $e");
      rethrow; 
    }
  }



  

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<DELETE OPERATIONS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
}