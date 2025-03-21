import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/product_model.dart';

class ProductService {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  // Fetch all products
  Future<List<ProductModel>> fetchAllProducts() async {
    try {
      // Get raw product data from FirebaseDAO without any filter
      final List<Map<String, dynamic>> rawProducts = await _firebaseDAO.getAllProducts();
      
      // Convert raw data to ProductModel objects
      final List<ProductModel> products = rawProducts.map((productData) {
        return ProductModel.fromMap(productData, docId: productData['id']);
      }).toList();
      
      return products;
    } catch (e) {
      print('Error fetching all products in ProductService: $e');
      // Return empty list on error
      return [];
    }
  }

  // Fetch products based on user's major
  Future<List<ProductModel>> fetchProductsByMajor() async {
    try {
      // Get the user's major
      final String? userMajor = await _firebaseDAO.getUserMajor();
      if (userMajor == null) {
        print('User major not found');
        return [];
      }

      // Get raw product data from FirebaseDAO with the user's major as filter
      final List<Map<String, dynamic>> rawProducts = await _firebaseDAO.getAllProducts(filter: userMajor);
      
      // Convert raw data to ProductModel objects
      final List<ProductModel> products = rawProducts.map((productData) {
        return ProductModel.fromMap(productData, docId: productData['id']);
      }).toList();
      
      return products;
    } catch (e) {
      print('Error fetching products by major in ProductService: $e');
      // Return empty list on error
      return [];
    }
  }
  
  // Create a new product
  Future<String?> createProduct(ProductModel product) async {
    try {
      // Convert ProductModel to Map
      final productData = product.toMap();
      
      // Create product in Firestore
      final productId = await _firebaseDAO.createProduct(productData);
      return productId;
    } catch (e) {
      print('Error creating product in ProductService: $e');
      return null;
    }
  }
  
  // Upload product image
  Future<String?> uploadProductImage(String filePath) async {
    return await _firebaseDAO.uploadProductImage(filePath);
  }
  
  // Get product by ID
  Future<ProductModel?> getProductById(String productId) async {
    try {
      final productData = await _firebaseDAO.getProductById(productId);
      if (productData != null) {
        return ProductModel.fromMap(productData, docId: productId);
      }
      return null;
    } catch (e) {
      print('Error getting product by ID in ProductService: $e');
      return null;
    }
  }
  
  // Update product
  Future<bool> updateProduct(String productId, ProductModel product) async {
    try {
      final productData = product.toMap();
      return await _firebaseDAO.updateProduct(productId, productData);
    } catch (e) {
      print('Error updating product in ProductService: $e');
      return false;
    }
  }
}