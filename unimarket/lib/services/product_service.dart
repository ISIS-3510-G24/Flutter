// File: lib/services/product_service.dart

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/models/queued_product_model.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/services/offline_queue_service.dart';
import 'package:path/path.dart' as path;

/// Service to handle product operations, both online and offline.
class ProductService {
  // Singleton implementation
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;

  ProductService._internal() {
    // 🔑 Inicializar la cola desde disco al crear la instancia
    _initializeService();
  }

  // Dependencies
  final OfflineQueueService _queueService = OfflineQueueService();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Internal cache for synchronous access
  List<QueuedProductModel> _latestQueue = [];
  bool _isInitialized = false;

  /// Initialize service - IMPROVED: Only initialize once
  Future<void> _initializeService() async {
    if (_isInitialized) {
      debugPrint('📦 ProductService already initialized');
      return;
    }

    try {
      debugPrint('🔧 Initializing ProductService');
      
      // Initialize queue service first
      await _queueService.initialize();
      debugPrint('✅ OfflineQueueService initialized');

      // Set up stream listener to keep cache synchronized
      _queueService.queueStream.listen((list) {
        _latestQueue = list;
        debugPrint('📋 Queue cache updated: ${list.length} items');
      });

      _isInitialized = true;
      debugPrint('✅ ProductService initialization complete');
    } catch (e, st) {
      debugPrint('🚨 Error initializing ProductService: $e\n$st');
      _isInitialized = false;
    }
  }

  /// Ensure service is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initializeService();
    }
  }

  /// Get the count of pending products (queued or failed)
  int get pendingProductsCount => _queueService.pendingCount;
  
  /// Get only pending products
  List<QueuedProductModel> get pendingProducts => _queueService.pendingProducts;
  
  /// Forward calls to the queue service
  Stream<List<QueuedProductModel>> get queuedProductsStream => _queueService.queueStream;
  
  List<QueuedProductModel> get queuedProductsSnapshot => _queueService.queuedProducts;
  
  Future<void> processQueue() async {
    await _ensureInitialized();
    return _queueService.processQueue();
  }
  
  Future<void> removeFromQueue(String id) async {
    await _ensureInitialized();
    return _queueService.removeFromQueue(id);
  }
  
  Future<void> retryQueuedUpload(String id) async {
    await _ensureInitialized();
    return _queueService.retryQueuedUpload(id);
  }
  
  Future<String> addToQueue(ProductModel product) async {
    await _ensureInitialized();
    return _queueService.addToQueue(product);
  }

  // --- Legacy compatibility ---

  /// No-op setter for older code expecting this method
  void setProductService(ProductService svc) {
    debugPrint('setProductService called (no-op)');
  }

  /// Synchronous access to all queued items
  List<QueuedProductModel> getQueuedProducts() => List.unmodifiable(_latestQueue);

  /// Legacy alias for synchronous access
  List<QueuedProductModel> getAllQueuedProducts() => getQueuedProducts();

  /// Legacy alias for retry
  Future<void> retryUpload(String queueId) => retryQueuedUpload(queueId);

  /// Check if there are pending uploads queued
  bool hasPendingUploads() {
    final has = _latestQueue.isNotEmpty;
    debugPrint('hasPendingUploads: $has');
    return has;
  }

  // --- Firestore CRUD operations ---

  /// Fetch all products, optional filtering by major
  Future<List<ProductModel>> fetchAllProducts({String? filter}) async {
    try {
      debugPrint('📡 Fetching all products${filter != null ? " (filter: $filter)" : ""}');
      final raw = await _firebaseDAO.getAllProducts(filter: filter);
      debugPrint('✅ Fetched ${raw.length} products from Firestore');
      return raw
        .map((m) => ProductModel.fromMap(m, docId: m['id'] as String))
        .toList();
    } catch (e) {
      debugPrint('🚨 Error fetching products: $e');
      return [];
    }
  }

  /// Fetch products by current user's major
  Future<List<ProductModel>> fetchProductsByMajor() async {
    try {
      final major = await _firebaseDAO.getUserMajor();
      if (major == null) {
        debugPrint('⚠️ No user major found');
        return [];
      }
      debugPrint('📡 Fetching products for major: $major');
      return fetchAllProducts(filter: major);
    } catch (e) {
      debugPrint('🚨 Error fetching products by major: $e');
      return [];
    }
  }

  /// Get a single product by ID
  Future<ProductModel?> getProductById(String id) async {
    try {
      debugPrint('📡 Fetching product by ID: $id');
      final map = await _firebaseDAO.getProductById(id);
      if (map == null) {
        debugPrint('⚠️ Product not found: $id');
        return null;
      }
      debugPrint('✅ Product found: $id');
      return ProductModel.fromMap(map, docId: id);
    } catch (e) {
      debugPrint('🚨 Error getProductById: $e');
      return null;
    }
  }

  /// Update existing product, falls back to offline queue if no connection
  Future<bool> updateProduct(String id, ProductModel product) async {
    await _ensureInitialized();
    
    final online = await _connectivityService.checkConnectivity();
    if (!online) {
      debugPrint('📵 Offline: queueing update for $id');
      await addToQueue(product.copyWith(id: id, updatedAt: DateTime.now()));
      return true;
    }
    
    try {
      debugPrint('📡 Updating product online: $id');
      final ok = await _firebaseDAO.updateProduct(id, product.toMap());
      debugPrint('✅ Product updated online: $ok');
      return ok;
    } catch (e) {
      debugPrint('🚨 Error updating product: $e');
      // Fallback to queue if online update fails
      await addToQueue(product.copyWith(id: id, updatedAt: DateTime.now()));
      return true;
    }
  }

  /// Create new product - IMPROVED: Always queue for better reliability
  Future<String?> createProduct(ProductModel product) async {
    await _ensureInitialized();
    
    debugPrint('📦 Creating product: ${product.title}');
    debugPrint('🖼️ Product has ${product.pendingImagePaths?.length ?? 0} pending images');
    debugPrint('☁️ Product has ${product.imageUrls.length} network images');
    
    // Always queue the product for more reliable handling
    return addToQueue(product);
  }

  // --- Image handling helpers ---

  /// Upload any pending local images, returning full list of URLs
  Future<List<String>> _uploadPendingImages(
      List<String>? pending, List<String> existing) async {
    final out = List<String>.from(existing);
    if (pending == null || pending.isEmpty) {
      debugPrint('ℹ️ No pending images to upload');
      return out;
    }
    
    debugPrint('⬆️ Uploading ${pending.length} pending images');
    for (var i = 0; i < pending.length; i++) {
      final pth = pending[i];
      debugPrint('⬆️ Uploading image ${i + 1}/${pending.length}: $pth');
      
      final url = await _uploadImage(pth);
      if (url != null) {
        out.add(url);
        debugPrint('✅ Image ${i + 1} uploaded successfully');
      } else {
        debugPrint('❌ Failed to upload image ${i + 1}');
      }
    }
    
    debugPrint('📊 Upload result: ${out.length - existing.length}/${pending.length} new images uploaded');
    return out;
  }

  /// Upload a single image file to Firebase Storage
  Future<String?> _uploadImage(String imagePath) async {
    debugPrint('🔄 _uploadImage start: $imagePath');
    try {
      final f = File(imagePath);
      if (!await f.exists()) {
        debugPrint('❌ File not found: $imagePath');
        throw 'Missing file: $imagePath';
      }
      
      final fileSize = await f.length();
      debugPrint('📏 File size: ${(fileSize / 1024).toInt()} KB');
      
      final name = path.basename(imagePath);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
        .ref('products/${_firebaseDAO.getCurrentUserId()}/$ts-$name');
      
      debugPrint('☁️ Starting Firebase upload...');
      final task = ref.putFile(f);
      final snap = await task.timeout(const Duration(seconds: 45));
      final url = await snap.ref.getDownloadURL();
      
      debugPrint('✅ _uploadImage success: $url');
      return url;
    } catch (e) {
      debugPrint('🚨 Upload error: $e');
      return null;
    }
  }

  /// Timeout-wrapped wrapper around DAO image upload
  Future<String?> uploadProductImage(String filePath) async {
    debugPrint('🔄 uploadProductImage called: $filePath');
    try {
      // Check if file exists before attempting upload
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ Image file does not exist: $filePath');
        return null;
      }
      
      final fileSize = await file.length();
      debugPrint('📏 Image file size: ${(fileSize / 1024).toInt()} KB');
      
      final url = await _firebaseDAO
        .uploadProductImage(filePath)
        .timeout(const Duration(seconds: 45));
      
      debugPrint('✅ uploadProductImage result: $url');
      return url;
    } on TimeoutException {
      debugPrint('⏱️ uploadProductImage timeout');
      return null;
    } catch (e) {
      debugPrint('🚨 uploadProductImage error: $e');
      return null;
    }
  }

  // --- Storage management ---

  /// Get storage statistics for debugging
  Future<Map<String, dynamic>> getStorageStats() async {
    await _ensureInitialized();
    return _queueService.getStorageStats();
  }

  /// Force cleanup of orphaned images
  Future<void> cleanupOrphanedImages() async {
    await _ensureInitialized();
    return _queueService.forceCleanupOrphanedImages();
  }

  // --- Queue management helpers ---

  /// Get queue summary for debugging
  Map<String, int> getQueueSummary() {
    final summary = <String, int>{};
    for (final status in ['queued', 'uploading', 'failed', 'completed']) {
      summary[status] = _latestQueue.where((q) => q.status == status).length;
    }
    return summary;
  }

  /// Print detailed queue status for debugging
  void printQueueStatus() {
    debugPrint('📋 ═══ QUEUE STATUS ═══');
    debugPrint('📊 Total items: ${_latestQueue.length}');
    
    final summary = getQueueSummary();
    for (final entry in summary.entries) {
      debugPrint('📊 ${entry.key}: ${entry.value}');
    }
    
    if (_latestQueue.isNotEmpty) {
      debugPrint('📋 Recent items:');
      for (final item in _latestQueue.take(3)) {
        final imageCount = item.product.pendingImagePaths?.length ?? 0;
        debugPrint('  • ${item.product.title} (${item.status}) - $imageCount images');
      }
    }
    debugPrint('📋 ═══════════════════');
  }

  /// Check service health
  Future<Map<String, dynamic>> getServiceHealth() async {
    await _ensureInitialized();
    
    final connectivity = await _connectivityService.checkConnectivity();
    final storageStats = await getStorageStats();
    final queueSummary = getQueueSummary();
    
    return {
      'isInitialized': _isInitialized,
      'hasInternet': connectivity,
      'queueSize': _latestQueue.length,
      'pendingUploads': queueSummary['queued'] ?? 0,
      'failedUploads': queueSummary['failed'] ?? 0,
      'storageStats': storageStats,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Force re-initialization (for debugging)
  Future<void> forceReinitialize() async {
    debugPrint('🔄 Force re-initializing ProductService');
    _isInitialized = false;
    await _initializeService();
  }
}