import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unimarket/models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ProductModel>> fetchProducts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('Product').get();
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }
}
