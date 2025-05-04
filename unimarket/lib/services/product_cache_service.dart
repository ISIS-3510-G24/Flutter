import 'dart:convert';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:unimarket/models/product_model.dart';

class ProductCacheService {
  static final ProductCacheService _instance = ProductCacheService._internal();
  factory ProductCacheService() => _instance;
  ProductCacheService._internal();

  // 1. CacheManager for filtered products (JSON)
  final CacheManager _filteredProductsCache = CacheManager(
    Config(
      'filteredProductsJsonCache',      // unique key
      stalePeriod: Duration(days: 1),   // expires in 1 day
      maxNrOfCacheObjects: 1,           // only store 1 file
    ),
  );
  
  // 2. LRU CacheManager for all products
  final CacheManager _allProductsCache = CacheManager(
    Config(
      'allProductsJsonCache',          // unique key
      stalePeriod: Duration(hours: 6), // expires sooner
      maxNrOfCacheObjects: 20,         // store more objects for LRU
    ),
  );
  
  // 3. Custom CacheManager for product images
  static final CacheManager productImageCacheManager = CacheManager(
    Config(
      'productImagesCache',
      stalePeriod: Duration(days: 7),   // images can be cached longer
      maxNrOfCacheObjects: 200,         // store more images
    ),
  );

  // Save filtered products to cache (as JSON)
  Future<void> saveFilteredProducts(List<ProductModel> products) async {
    final jsonList = products.map((p) => p.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    // Save JSON to cache
    await _filteredProductsCache.putFile(
      'filtered_products',               // internal key
      utf8.encode(jsonString),           // JSON bytes
      fileExtension: 'json',
    );

    // Pre-cache images
    await Future.wait(products.where((p) => p.imageUrls.isNotEmpty)
        .map((p) => _precacheImage(p.imageUrls.first)));
  }

  // Load filtered products from cache
  Future<List<ProductModel>> loadFilteredProducts() async {
    final fileInfo = await _filteredProductsCache.getFileFromCache('filtered_products');
    if (fileInfo != null && await fileInfo.file.exists()) {
      final jsonString = await fileInfo.file.readAsString();
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => ProductModel.fromJson(e)).toList();
    }
    return [];
  }
  
  // NEW: Save all products to LRU cache
  Future<void> saveAllProducts(List<ProductModel> products) async {
    final jsonList = products.map((p) => p.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    // Save JSON to LRU cache
    await _allProductsCache.putFile(
      'all_products',                   // internal key
      utf8.encode(jsonString),          // JSON bytes
      fileExtension: 'json',
    );
    
    // Pre-cache first few product images to avoid overloading
    final imagesToPreload = products
        .where((p) => p.imageUrls.isNotEmpty)
        .take(10)                      // Only preload first 10 images
        .map((p) => p.imageUrls.first);
        
    await Future.wait(imagesToPreload.map(_precacheImage));
  }
  
  // NEW: Load all products from LRU cache
  Future<List<ProductModel>> loadAllProductsFromCache() async {
    final fileInfo = await _allProductsCache.getFileFromCache('all_products');
    if (fileInfo != null && await fileInfo.file.exists()) {
      final jsonString = await fileInfo.file.readAsString();
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => ProductModel.fromJson(e)).toList();
    }
    return [];
  }

  // Helper to precache an image
  Future<void> _precacheImage(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await productImageCacheManager.getSingleFile(url);
    } catch (e) {
      print("Error precaching image $url: $e");
      // If failed, we do nothing
    }
  }
  
  // Clear old cached images (call periodically to free up space)
  Future<void> clearOldCache() async {
    await productImageCacheManager.emptyCache();
    await _allProductsCache.emptyCache();
    // Don't clear filtered cache as it's more important
  }
}