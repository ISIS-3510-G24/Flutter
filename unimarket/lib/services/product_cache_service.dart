import 'dart:async';
import 'dart:convert';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:unimarket/models/product_model.dart';

// Custom HTTP client to limit concurrent requests
class LoggingHttpClient extends http.BaseClient {
  final http.Client _client = http.Client();
  final int maxConcurrent;
  final Set<Uri> _inProgress = {};
  final List<_QueuedRequest> _queue = [];
  
  LoggingHttpClient({this.maxConcurrent = 4});
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_inProgress.length >= maxConcurrent) {
      // Queue the request
      final completer = Completer<http.StreamedResponse>();
      _queue.add(_QueuedRequest(request, completer));
      return completer.future;
    }
    
    return _processSend(request);
  }
  
  Future<http.StreamedResponse> _processSend(http.BaseRequest request) async {
    _inProgress.add(request.url);
    try {
      return await _client.send(request);
    } finally {
      _inProgress.remove(request.url);
      // Process next queued request if any
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        next.completer.complete(_processSend(next.request));
      }
    }
  }
  
  @override
  void close() {
    _client.close();
    super.close();
  }
}

class _QueuedRequest {
  final http.BaseRequest request;
  final Completer<http.StreamedResponse> completer;
  
  _QueuedRequest(this.request, this.completer);
}

class ProductCacheService {
  static final ProductCacheService _instance = ProductCacheService._internal();
  factory ProductCacheService() => _instance;
  ProductCacheService._internal();

  // 1. CacheManager for filtered products (JSON)
  final CacheManager _filteredProductsCache = CacheManager(
    Config(
      'filteredProductsJsonCache',      // unique key
      stalePeriod: const Duration(days: 1),   // expires in 1 day
      maxNrOfCacheObjects: 1,           // only store 1 file
    ),
  );
  
  // 2. LRU CacheManager for all products
  final CacheManager _allProductsCache = CacheManager(
    Config(
      'allProductsJsonCache',          // unique key
      stalePeriod: const Duration(hours: 6), // expires sooner
      maxNrOfCacheObjects: 20,         // store more objects for LRU
    ),
  );
  
  // 3. Custom CacheManager for product images with optimized HTTP client
  static final CacheManager productImageCacheManager = CacheManager(
    Config(
      'productImagesCache',
      stalePeriod: const Duration(days: 7),   // images can be cached longer
      maxNrOfCacheObjects: 100,        // Reduced from 200 to save memory
      fileService: HttpFileService(     // Add custom HTTP client
        httpClient: LoggingHttpClient(maxConcurrent: 4), // Limit concurrent requests
      ),
    ),
  );

  // Save filtered products to cache (as JSON)
  Future<void> saveFilteredProducts(List<ProductModel> products) async {
    final jsonList = products.map((p) => p.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

   await _filteredProductsCache.putFile(
  'filtered_products',               
  utf8.encode(jsonString),  // Eliminado "as List<int>"
  fileExtension: 'json',
);

    // Use improved precaching method
    await _precacheImages(products);
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
  
  // Save all products to LRU cache
  Future<void> saveAllProducts(List<ProductModel> products) async {
    final jsonList = products.map((p) => p.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

   await _allProductsCache.putFile(
  'all_products',                   
  utf8.encode(jsonString),  // Eliminado "as List<int>"
  fileExtension: 'json',
);
    
    // Use improved precaching method with the first few images
    final productsToPreload = products.take(10).toList();
    await _precacheImages(productsToPreload);
  }
  
  // Load all products from LRU cache
  Future<List<ProductModel>> loadAllProductsFromCache() async {
    final fileInfo = await _allProductsCache.getFileFromCache('all_products');
    if (fileInfo != null && await fileInfo.file.exists()) {
      final jsonString = await fileInfo.file.readAsString();
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => ProductModel.fromJson(e)).toList();
    }
    return [];
  }

  // Improved pre-cache with prioritization and batching
  Future<void> _precacheImages(List<ProductModel> products) async {
    // First filter for unique URLs to avoid duplicate requests
    final uniqueUrls = <String>{};
    final urlsToLoad = <String>[];
    
    for (final product in products) {
      if (product.imageUrls.isNotEmpty) {
        final url = product.imageUrls.first;
        if (url.isNotEmpty && !uniqueUrls.contains(url)) {
          uniqueUrls.add(url);
          urlsToLoad.add(url);
        }
      }
    }
    
    // Process in smaller batches to avoid memory spikes
    for (int i = 0; i < urlsToLoad.length; i += 5) {
      final end = (i + 5 < urlsToLoad.length) ? i + 5 : urlsToLoad.length;
      final batch = urlsToLoad.sublist(i, end);
      
      await Future.wait(batch.map((url) => _precacheImage(url)));
      // Add a small delay between batches
      if (end < urlsToLoad.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  // Updated precache method with file existence check
  Future<void> _precacheImage(String url) async {
    if (url.isEmpty) return;
    
    try {
      // Check if file already exists in cache before downloading
      final fileInfo = await productImageCacheManager.getFileFromCache(url);
      if (fileInfo != null) {
        // Already cached
        return;
      }
      
      // Not in cache, download it
      await productImageCacheManager.getSingleFile(url)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('Image download timed out');
      });
    } catch (e) {
      print("Error precaching image $url: $e");
    }
  }
  
  // Clear old cached images (call periodically to free up space)
  Future<void> clearOldCache() async {
    await productImageCacheManager.emptyCache();
    await _allProductsCache.emptyCache();
    // Don't clear filtered cache as it's more important
  }
}