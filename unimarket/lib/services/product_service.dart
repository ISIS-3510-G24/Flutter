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

  
   // dependencias
  final OfflineQueueService _queueService = OfflineQueueService();

  ProductService._internal() {
    // 🔑 >>> inicializa carga de la cola desde disco
    _queueService.initialize();                 // <--  NUEVA LÍNEA

    // mantén sincronizada la caché interna
    _queueService.queueStream.listen((list) {
      _latestQueue = list;
      debugPrint('📋 Queue updated: ${list.length} items');
    });
  }


  // Stream para el UI
  Stream<List<QueuedProductModel>> get queuedProductsStream =>
      _queueService.queueStream;

  // Snapshot sincrónico (lo usamos como `initialData`)
  List<QueuedProductModel> get queuedProductsSnapshot =>
      _queueService.queuedProducts;

  // Dependencies
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Internal cache for synchronous access
  List<QueuedProductModel> _latestQueue = [];

  // --- Legacy compatibility ---

  /// No-op setter for older code expecting this method
  void setProductService(ProductService svc) {
    debugPrint('setProductService called (no-op)');
  }

  /// Synchronous access to all queued items
  List<QueuedProductModel> getQueuedProducts() => List.unmodifiable(_latestQueue);

  /// Legacy alias for synchronous access
  List<QueuedProductModel> getAllQueuedProducts() => getQueuedProducts();


  /// Add a product to the offline queue
  Future<String> addToQueue(ProductModel product) {
    debugPrint('Adding product to queue: ${product.title}');
    return _queueService.addToQueue(product);
  }

 Future<void> retryQueuedUpload(String id) async {
  debugPrint('🔄 Reintentando subida: $id');
  try {
    await _queueService.retryQueuedUpload(id);
    // Si estamos online, procesar la cola inmediatamente
    if (_connectivityService.hasInternetAccess) {
      debugPrint('🌐 Online, procesando cola después de reintento');
      processQueue();
    }
    debugPrint('✅ Reintento programado: $id');
  } catch (e) {
    debugPrint('❌ Error al reintentar subida $id: $e');
  }
}

  /// Legacy alias for retry
  Future<void> retryUpload(String queueId) => retryQueuedUpload(queueId);

 Future<void> removeFromQueue(String id) async {
  debugPrint('🗑️ Removiendo producto de la cola: $id');
  try {
    await _queueService.removeFromQueue(id);
    // Notificar a los listeners si es necesario
    debugPrint('✅ Producto removido de la cola: $id');
  } catch (e) {
    debugPrint('❌ Error al remover producto $id: $e');
  }
}

  /// Check if there are pending uploads queued
  bool hasPendingUploads() {
    final has = _latestQueue.isNotEmpty;
    debugPrint('hasPendingUploads: $has');
    return has;
  }

 Future<void> processQueue() async {
  debugPrint('🔄 ProductService.processQueue() llamado');
  try {
    await _queueService.processQueue();
    debugPrint('✅ Cola procesada desde ProductService');
  } catch (e) {
    debugPrint('❌ Error al procesar cola desde ProductService: $e');
  }
}

  // --- Firestore CRUD operations ---

  /// Fetch all products, optional filtering by major
  Future<List<ProductModel>> fetchAllProducts({String? filter}) async {
    try {
      final raw = await _firebaseDAO.getAllProducts(filter: filter);
      debugPrint('Fetched all products (${raw.length})');
      return raw
        .map((m) => ProductModel.fromMap(m, docId: m['id'] as String))
        .toList();
    } catch (e) {
      debugPrint('Error fetching products: $e');
      return [];
    }
  }

  /// Fetch products by current user's major
  Future<List<ProductModel>> fetchProductsByMajor() async {
    final major = await _firebaseDAO.getUserMajor();
    if (major == null) {
      debugPrint('No user major found');
      return [];
    }
    debugPrint('Fetching products for major: $major');
    return fetchAllProducts(filter: major);
  }

  /// Get a single product by ID
  Future<ProductModel?> getProductById(String id) async {
    try {
      final map = await _firebaseDAO.getProductById(id);
      if (map == null) {
        debugPrint('Product not found: $id');
        return null;
      }
      return ProductModel.fromMap(map, docId: id);
    } catch (e) {
      debugPrint('Error getProductById: $e');
      return null;
    }
  }

  /// Update existing product, falls back to offline queue if no connection
  Future<bool> updateProduct(String id, ProductModel product) async {
    final online = await _connectivityService.checkConnectivity();
    if (!online) {
      debugPrint('Offline: queueing update for $id');
      await addToQueue(product.copyWith(id: id, updatedAt: DateTime.now()));
      return true;
    }
    try {
      final ok = await _firebaseDAO.updateProduct(id, product.toMap());
      debugPrint('Product updated online: $ok');
      return ok;
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  /// Create new product, with offline fallback
  Future<String?> createProduct(ProductModel product) async {
    final online = await _connectivityService.checkConnectivity();
    if (!online) {
      debugPrint('Offline: queueing creation for ${product.title}');
      return addToQueue(product);
    }
    try {
      final urls = await _uploadPendingImages(
        product.pendingImagePaths, product.imageUrls
      );
      final data = product.copyWith(
        imageUrls: urls,
        pendingImagePaths: [],
        updatedAt: DateTime.now()
      ).toMap();
      final id = await _firebaseDAO.createProduct(data);
      debugPrint('Product created online with ID: $id');
      return id;
    } catch (e) {
      debugPrint('Online create failed, queueing: $e');
      return addToQueue(product);
    }
  }

  // --- Image handling helpers ---

  /// Upload any pending local images, returning full list of URLs
  Future<List<String>> _uploadPendingImages(
      List<String>? pending, List<String> existing) async {
    final out = List<String>.from(existing);
    if (pending == null) return out;
    for (var pth in pending) {
      final url = await _uploadImage(pth);
      if (url != null) out.add(url);
    }
    return out;
  }

  /// Upload a single image file to Firebase Storage
  Future<String?> _uploadImage(String imagePath) async {
    debugPrint('🔄 _uploadImage start: $imagePath');
    try {
      final f = File(imagePath);
      if (!await f.exists()) throw 'Missing file: $imagePath';
      final name = path.basename(imagePath);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
        .ref('products/${_firebaseDAO.getCurrentUserId()}/$ts-$name');
      final task = ref.putFile(f);
      final snap = await task.timeout(const Duration(seconds: 30));
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
    debugPrint('uploadProductImage called: $filePath');
    try {
      final url = await _firebaseDAO
        .uploadProductImage(filePath)
        .timeout(const Duration(seconds: 30));
      debugPrint('uploadProductImage result: $url');
      return url;
    } on TimeoutException {
      debugPrint('⏱️ uploadProductImage timeout');
      return null;
    } catch (e) {
      debugPrint('🚨 uploadProductImage error: $e');
      return null;
    }
  }
}
