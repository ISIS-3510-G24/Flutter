import 'package:unimarket/models/product_model.dart';

class AlgoliaAdapter {
  // Convierte un resultado de Algolia a ProductModel
  static ProductModel convertToProductModel(Map<String, dynamic> algoliaData) {
    try {
      // Extrae los campos necesarios
      String id = algoliaData['objectID'] ?? '';
      
      // Campo classId
      String classId = algoliaData['classId'] ?? '1815'; // Valor predeterminado
      
      // Campo createdAt - Convertir timestamp de Algolia (entero) a DateTime
      DateTime createdAt;
      if (algoliaData['createdAt'] is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(algoliaData['createdAt'] as int);
      } else {
        createdAt = DateTime.now();
      }
      
      // Campos de texto
      String description = algoliaData['description'] ?? '';
      String title = algoliaData['title'] ?? '';
      String status = algoliaData['status'] ?? 'Available';
      String sellerID = algoliaData['sellerID'] ?? '';
      String majorID = algoliaData['majorID'] ?? '';
      
      // Campo updatedAt
      DateTime updatedAt;
      if (algoliaData['updatedAt'] is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(algoliaData['updatedAt'] as int);
      } else {
        updatedAt = DateTime.now();
      }
      
      // Precio
      double price = 0.0;
      if (algoliaData['price'] is int) {
        price = (algoliaData['price'] as int).toDouble();
      } else if (algoliaData['price'] is double) {
        price = algoliaData['price'];
      } else if (algoliaData['price'] is String) {
        try {
          price = double.parse(algoliaData['price']);
        } catch (_) {}
      }
      
      // Imágenes
      List<String> imageUrls = [];
      if (algoliaData['imageUrls'] != null) {
        if (algoliaData['imageUrls'] is List) {
          imageUrls = List<String>.from(
            (algoliaData['imageUrls'] as List).map((item) => item.toString())
          );
        } else if (algoliaData['imageUrls'] is String) {
          imageUrls = [algoliaData['imageUrls'] as String];
        }
      }
      
      // Labels
      List<String> labels = [];
      if (algoliaData['labels'] != null) {
        if (algoliaData['labels'] is List) {
          labels = List<String>.from(
            (algoliaData['labels'] as List).map((item) => item.toString())
          );
        } else if (algoliaData['labels'] is String) {
          labels = [algoliaData['labels'] as String];
        }
      }
      
      // Crear el ProductModel con todos los campos requeridos
      return ProductModel(
        id: id,
        classId: classId,
        createdAt: createdAt,
        description: description,
        imageUrls: imageUrls,
        labels: labels,
        majorID: majorID,
        price: price,
        sellerID: sellerID,
        status: status,
        title: title,
        updatedAt: updatedAt,
      );
    } catch (e) {
      print('Error convirtiendo datos de Algolia: $e');
      
      // En caso de error, devolver un modelo con valores predeterminados
      return ProductModel(
        id: null,
        classId: '1815',
        createdAt: DateTime.now(),
        description: '',
        imageUrls: [],
        labels: [],
        majorID: '',
        price: 0,
        sellerID: '',
        status: 'Available',
        title: '',
        updatedAt: DateTime.now(),
      );
    }
  }
}