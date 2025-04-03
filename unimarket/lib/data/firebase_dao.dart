import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/models/order_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/models/find_model.dart'; 
import 'package:unimarket/models/offer_model.dart'; 
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';


class FirebaseDAO {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

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

Future<bool> createUser(String email, String password, String bio, String displayName, String major )async {
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

  Future<List<Map<String, dynamic>>> getAllProducts({String? filter}) async {
    try {
      Query query = _firestore.collection('Product');

      if (filter != null && filter.isNotEmpty) {
        query = query.where('majorID', isEqualTo: filter);
      }

      QuerySnapshot querySnapshot = await query.get();
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

   Future<String?> getUserMajor() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) return null;

      final doc = await _firestore.collection('User').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['major'] as String?;
      }
      return null;
    } catch (e) {
      print("Error getting user major: $e");
      return null;
    }
  }


  Future<bool> checkSellerReviews(String sellerId) async {
  try {
    // Obtener las 3 reseñas mas recientes excluyendo el placeholder
    QuerySnapshot reviewSnapshot = await FirebaseFirestore.instance
        .collection('User')
        .doc(sellerId)
        .collection('reviews')
        .where(FieldPath.documentId, isNotEqualTo: 'placeholder')
        .orderBy('createdAt', descending: true) 
        .limit(3) 
        .get();

    // Revisar que las 3 sean ratings mayores a 3
    bool allReviewsAbove3 = reviewSnapshot.docs.every((doc) {
      final reviewData = doc.data() as Map<String, dynamic>;
      final score = reviewData['rating'] as int; 
      return score > 3;
    });

    return allReviewsAbove3;
  } catch (e) {
    print("Error fetching reviews: $e");
    return false;
  }
}

Future<List<String>> getLabelsByOrder(String orderId) async {
  DocumentSnapshot orderSnapshot = await _firestore.collection('orders').doc(orderId).get();
  if (!orderSnapshot.exists) return [];
  String productId = orderSnapshot.get('productID');

  DocumentSnapshot productSnapshot = await _firestore.collection('Product').doc(productId).get();
  if (!productSnapshot.exists) return [];

  return List<String>.from(productSnapshot.get('labels') ?? []);
}



//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<CREATE OPERATIONS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

//Helper function for sendPreferencesToFirebase
List<String> getPreferenceCodes(Set<String> selectedPreferences) {
    final Map<String, List<String>> preferenceCodes = {
  'Academics and Education': ['Academics', 'Education'],
  'Technology, Electronics and Engineering': ['Technology', 'Electronics','Engineering'],
  'Art and Design': ['Art', 'Design'],
  'Handcrafts': ['Handcrafts'],
  'Fashion and Accessories': ['Fashion', 'Accessories'],
  'Sports and Wellness': ['Sports', 'Wellness'],
  'Entertainment': ['Entertainment'],
  'Home and Decoration': ['Home','Decoration'],
  'Other':['Other']
};
  List<String> codes = [];
  for (String preference in selectedPreferences) {
    if (preferenceCodes.containsKey(preference)) {
      codes.addAll(preferenceCodes[preference]!);
    }
  }
  return codes;
}

Future<bool> sendPreferencesToFirebase ( Set<String> selectedPreferences)async {
  final userId = getCurrentUserId();
    if (userId == null) {
      print("No user is currently logged in.");
      return false;
    }
 List<String> preferences = getPreferenceCodes(selectedPreferences);

  try {
    await _firestore.collection('User').doc(userId).update({
      'preferences': preferences,
    });
    print("Preferences updated successfully.");
    return true;
  } catch (e) {
    print("Error updating preferences: $e");
    return false;
  }
}


Future<String?> uploadImageToStorage(XFile image) async {
    try {
      //Nombre dependiente del tiempo de upload para que no hayan duplicados
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child('product_images/$fileName.jpg');
      UploadTask uploadTask = ref.putFile(File(image.path));

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  Future<XFile?> pickImage(ImageSource source) async {
    return await _picker.pickImage(source: source);
  }

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
//Metodo para sumar 1 a cada label cuando se compra un producto
void updatePurchaseMetrics(List<String> labels) {
  DocumentReference purchaseCountRef = FirebaseFirestore.instance
      .collection('label_metrics')
      .doc('purchase_count');
  Map<String, dynamic> updates = {};
  for (String label in labels) {
    updates[label] = FieldValue.increment(1);
  }
  purchaseCountRef.set(updates, SetOptions(merge: true));
}
//Metodo para sumar 1 a cada label cuando se filtra por ese label
//TODO: Implementar filtrar por labels
void updateFilterMetrics(String label) {
  FirebaseFirestore.instance
      .collection('label_metrics')
      .doc('filter_count')
      .set({label: FieldValue.increment(1)}, SetOptions(merge: true));
}
//Metodo para sumar 1 a cada label cuando se genera un producto
void updateProductPlacementMetrics(List<String> labels) {
  DocumentReference purchaseCountRef = FirebaseFirestore.instance
      .collection('label_metrics')
      .doc('product_placement_count');
  Map<String, dynamic> updates = {};
  for (String label in labels) {
    updates[label] = FieldValue.increment(1);
  }
  purchaseCountRef.set(updates, SetOptions(merge: true));
}



  

//<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<DELETE OPERATIONS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


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

// Consistent wishlist implementation
Future<bool> addToWishlist(String productId) async {
  final userId = getCurrentUserId();
  if (userId == null) {
    return false;
  }
  
  try {
    await _firestore
        .collection('User')
        .doc(userId)
        .collection('wishlist')
        .doc(productId)
        .set({
      'productID': productId,
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
    await _firestore
        .collection('User')
        .doc(userId)
        .collection('wishlist')
        .doc(productId)
        .delete();
    return true;
  } catch (e) {
    print("Error removing from wishlist: $e");
    return false;
  }
}

// WISHLIST
Future<List<String>> getUserWishlist() async {
  final userId = getCurrentUserId();
  if (userId == null) {
    return [];
  }
  
  try {
    final querySnapshot = await _firestore
        .collection('User')
        .doc(userId)
        .collection('wishlist')
        .get();
    
    // Extract product IDs from wishlist documents
    return querySnapshot.docs
        .map((doc) => doc.data()['productID'] as String)
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

Future<List<Map<String, dynamic>>> getWishlistProducts() async {
  try {
    // Get wishlist product IDs
    final wishlistIds = await getUserWishlist();
    List<Map<String, dynamic>> products = [];
    
    // If we have wishlist IDs, fetch the products
    if (wishlistIds.isNotEmpty) {
      // Use the correct collection name and batch get
      final productsQuery = await _firestore
          .collection('Product')
          .where(FieldPath.documentId, whereIn: wishlistIds)
          .get();
      
      for (var doc in productsQuery.docs) {
        final productData = doc.data();
        productData['id'] = doc.id; // Add the ID to the data
        products.add(productData);
      }
    }
    
    return products;
  } catch (e) {
    print("Error getting wishlist products: $e");
    return [];
  }
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

//======find and offer methods========
// Find and Offer methods with improved error handling
  Future<List<FindModel>> getFind() async {
    try {
      print("Fetching find from Firestore...");
      final snapshot = await _firestore.collection('finds').get();
      print("Fetched ${snapshot.docs.length} finds.");
      
      List<FindModel> finds = [];
      for (var doc in snapshot.docs) {
        try {
          print("Processing find ID: ${doc.id}, Data: ${doc.data()}");
          finds.add(FindModel.fromFirestore(doc.data(), doc.id));
        } catch (e) {
          print("Error parsing find with ID ${doc.id}: $e");
          // Continue to next document instead of failing entire query
        }
      }
      return finds;
    } catch (e) {
      print("Error fetching the find objects: $e");
      return [];
    }
  }

  Future<List<OfferModel>> getOffersForFind(String findId) async {
    try {
      print("Fetching offers for find ID: $findId from Firestore...");
      final snapshot = await _firestore.collection('finds').doc(findId).collection('offers').get();
      print("Fetched ${snapshot.docs.length} offers for find ID: $findId.");
      
      List<OfferModel> offers = [];
      for (var doc in snapshot.docs) {
        try {
          print("Processing offer ID: ${doc.id}, Data: ${doc.data()}");
          offers.add(OfferModel.fromFirestore(doc.data(), doc.id));
        } catch (e) {
          print("Error parsing offer with ID ${doc.id}: $e");
          // Continue to next document instead of failing entire query
        }
      }
      return offers;
    } catch (e) {
      print("Error fetching offers for find ID $findId: $e");
      return [];
    }
  }

// Get finds by major
  Future<List<FindModel>> getFindsByMajor(String major) async {
    try {
      print("Fetching finds for major: $major from Firestore...");
      final snapshot = await _firestore
          .collection('finds')
          .where('major', isEqualTo: major)
          .get();
      
      print("Fetched ${snapshot.docs.length} finds for major: $major");
      
      List<FindModel> finds = [];
      for (var doc in snapshot.docs) {
        try {
          print("Processing find ID: ${doc.id}, Data: ${doc.data()}");
          finds.add(FindModel.fromFirestore(doc.data(), doc.id));
        } catch (e) {
          print("Error parsing find with ID ${doc.id}: $e");
          // Continue to next document instead of failing entire query
        }
      }
      return finds;
    } catch (e) {
      print("Error fetching finds by major: $e");
      return [];
    }
  }

   Future<void> createFind({
    required String title,
    required String description,
    String? image,
    required String major,
    required List<String> labels,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User is not authenticated");
    }

    final find = FindModel(
      id: _firestore.collection('finds').doc().id,
      title: title,
      description: description,
      image: image ?? '',
      labels: labels,
      major: major,
      offerCount: 1,
      status: 'active',
      timestamp: DateTime.now(),
      upvoteCount: 0,
      userId: user.uid,
      userName: user.displayName ?? 'Anonymous',
    );

    await _firestore.collection('finds').doc(find.id).set(find.toMap());
  }

  Future<void> createOffer({
    required String findId,
    required String userName,
    required String description,
    String? image,
    required int price, 
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User is not authenticated");
    }

    final offer = OfferModel(
      id: _firestore.collection('finds').doc(findId).collection('offers').doc().id,
      userName: userName,
      description: description,
      image: image ?? '',
      price: price, // Use int
      status: 'pending',
      timestamp: DateTime.now(),
      userId: user.uid,
    );

    await _firestore.collection('finds').doc(findId).collection('offers').doc(offer.id).set(offer.toMap());
  }
}