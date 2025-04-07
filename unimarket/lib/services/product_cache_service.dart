import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:http/http.dart' as http;

class ProductCacheService {
  static final ProductCacheService _instance = ProductCacheService._internal();
  factory ProductCacheService() => _instance;
  
  ProductCacheService._internal();
  
  // Obtener directorio para almacenamiento
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
  
  // Obtener ruta del archivo de productos personalizados
  Future<File> get _filteredProductsFile async {
    final path = await _localPath;
    return File('$path/filtered_products_cache.json');
  }
  
  // Obtener ruta del archivo para imágenes en caché
  Future<String> get _imagesCachePath async {
    final path = await _localPath;
    final imagesDir = Directory('$path/product_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir.path;
  }
  
 // Modifica la función saveFilteredProductsToCache en tu ProductCacheService.dart

Future<void> saveFilteredProductsToCache(List<ProductModel> filteredProducts) async {
  try {
    final file = await _filteredProductsFile;
    
    // Aquí está la corrección: Asegurarnos de que los objetos JSON no tengan valores nulos para 'id'
    final jsonList = filteredProducts.map((product) {
      final json = product.toJson();
      // Si el id es nulo, genera uno temporal
      if (json['id'] == null) {
        json['id'] = 'temp_${DateTime.now().millisecondsSinceEpoch}_${filteredProducts.indexOf(product)}';
      }
      return json;
    }).toList();
    
    // Guardar productos personalizados con IDs seguros
    await file.writeAsString(jsonEncode(jsonList));
    
    print("Filtered products saved to cache successfully");
    
    // Precargar imágenes
    for (var i = 0; i < filteredProducts.length; i++) {
      final product = filteredProducts[i];
      final productId = jsonList[i]['id'] as String; // Usar el ID que acabamos de asegurar
      
      if (product.imageUrls.isNotEmpty && product.imageUrls.first != null) {
        await precacheProductImage(productId, product.imageUrls.first);
      }
    }
  } catch (e) {
    print("Error saving filtered products to cache: $e");
  }
}
  // Cargar productos personalizados desde caché
  Future<List<ProductModel>> loadFilteredProductsFromCache() async {
    try {
      final file = await _filteredProductsFile;
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        
        final products = jsonList
            .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
            .toList();
        
        print("Filtered products loaded from cache successfully");
        return products;
      }
    } catch (e) {
      print("Error loading filtered products from cache: $e");
    }
    
    return []; // Retornar lista vacía si hay error o no hay caché
  }
  
  // Precargar y guardar imagen localmente (método público para poder llamarlo desde SplashScreen)
  Future<void> precacheProductImage(String productId, String? imageUrl) async {
    // Si la URL es nula, salir de la función
    if (imageUrl == null) return;
    try {
      final imagesPath = await _imagesCachePath;
      final imageFileName = '$imagesPath/${productId}_main.jpg';
      final imageFile = File(imageFileName);
      
      // Verificar si la imagen ya existe en caché
      if (await imageFile.exists()) {
        return; // La imagen ya está en caché
      }
      
      // Descargar y guardar la imagen
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        await imageFile.writeAsBytes(response.bodyBytes);
        print("Image for product $productId cached successfully");
      }
    } catch (e) {
      print("Error caching image for product $productId: $e");
    }
  }
  
  // Obtener ruta local de la imagen si está en caché
  Future<String?> getLocalImagePath(String productId) async {
    try {
      final imagesPath = await _imagesCachePath;
      final imageFileName = '$imagesPath/${productId}_main.jpg';
      final imageFile = File(imageFileName);
      
      if (await imageFile.exists()) {
        return imageFileName;
      }
    } catch (e) {
      print("Error getting local image path: $e");
    }
    
    return null; // Retornar null si no existe la imagen en caché
  }
  
  // Limpiar caché de imágenes más antiguas (opcional, para liberar espacio)
  Future<void> cleanupOldImages(List<String> activeProductIds) async {
    try {
      final imagesPath = await _imagesCachePath;
      final directory = Directory(imagesPath);
      final files = await directory.list().toList();
      
      for (var entity in files) {
        if (entity is File) {
          // Extraer ID del producto del nombre del archivo
          final fileName = entity.path.split('/').last;
          final productId = fileName.split('_').first;
          
          // Si el ID no está en la lista de productos activos, eliminar la imagen
          if (!activeProductIds.contains(productId)) {
            await entity.delete();
            print("Deleted old cached image: ${entity.path}");
          }
        }
      }
    } catch (e) {
      print("Error cleaning up old images: $e");
    }
  }
}