import 'package:unimarket/data/image_storage_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unimarket/models/queued_product_model.dart';
import 'package:unimarket/models/queued_order_model.dart';
import 'package:uuid/uuid.dart';

import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/product_model.dart';

class OfflineQueueService {
  // ---- Singleton ----
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();
  
  final ImageStorageService _imageStorage = ImageStorageService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  List<QueuedProductModel> _queuedProducts = [];
  bool _isProcessing = false;
  List<QueuedOrderModel> _queuedOrders = [];
  bool _isProcessingOrders = false;
  Timer? _processingTimer;
  StreamSubscription? _connectivitySubscription;

  // ---- Constantes ----
  static const String _storageKey = 'offline_product_queue';
  static const String _completedStorageKey = 'completed_product_history';
  static const String _qrscanKey = 'product_delivery_queue';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(minutes: 5);

  // ---- **** Stream **** ----
  final _internalController =
      StreamController<List<QueuedProductModel>>.broadcast();

  Stream<List<QueuedProductModel>> get queueStream =>
      Stream.multi((controller) {
        controller.add(List.unmodifiable(_queuedProducts));
        final sub = _internalController.stream.listen(controller.add);
        controller.onCancel = () => sub.cancel();
      });

  List<QueuedProductModel> get queuedProducts =>
      List.unmodifiable(_queuedProducts);

  // Get only pending products (queued or failed) 
  List<QueuedProductModel> get pendingProducts =>
      _queuedProducts.where((p) => p.status == 'queued' || p.status == 'failed').toList();

  int get pendingCount => pendingProducts.length;

  Future<void> initialize() async {
    debugPrint('🔧 Initializing OfflineQueueService');
    try {
      // Initialize image storage service first
      await _imageStorage.initialize();
      debugPrint('📸 ImageStorageService initialized');
      
      await _loadQueuedProducts();
      await _loadCompletedProducts();
      await _loadOrders();
      
      // Validate image paths after loading
      await _validateAndCleanupImagePaths();
      
      // Clean up orphaned images
      await _cleanupOrphanedImages();
      
      debugPrint('📦 Loaded ${_queuedProducts.length} products in queue');
      
      _connectivitySubscription?.cancel();
      _connectivitySubscription = _connectivityService.connectivityStream.listen(_onConnectivityChange);
      debugPrint('🔌 Connectivity listener configured');
      
      _setupPeriodicCheck();
      debugPrint('⏰ Periodic check configured');
      
      _processIfOnline();
      
      debugPrint('✅ OfflineQueueService initialized correctly');
    } catch (e, st) {
      debugPrint('🚨 Error initializing OfflineQueueService: $e\n$st');
      _queuedProducts = [];
      _notify();
    }
  }

  void _onConnectivityChange(bool hasInternet) {
    debugPrint('🔌 Connectivity change detected: $hasInternet');
    
    if (hasInternet) {
      // AUTOMATIC UPLOAD when internet returns
      Future.delayed(const Duration(seconds: 2), () async {
        if (await _connectivityService.checkConnectivity()) {
          debugPrint('🔌 Connection confirmed, AUTO-PROCESSING queue...');
          processQueue();
          processOrderQueue();
        }
      });
    }
  }

  void _setupPeriodicCheck() {
    _processingTimer?.cancel();
    _processingTimer =
        Timer.periodic(const Duration(minutes: 15), (_) => _processIfOnline());
    debugPrint('⏱️ Verification timer configured (every 15 min)');
  }

  Future<void> _processIfOnline() async {
    debugPrint('🔍 Checking connectivity to process queue...');
    
    // Check for pending items first
    final pendingItems = _queuedProducts.where((qp) =>
        qp.status == 'queued' || qp.status == 'failed').toList();
    
    if (pendingItems.isEmpty) {
      debugPrint('ℹ️ No pending items to process');
      return;
    }
    
    if (await _connectivityService.checkConnectivity()) {
      debugPrint('✅ Connection available, processing ${pendingItems.length} pending items');
      processQueue();
      processOrderQueue();
    } else {
      debugPrint('❌ No connection, ${pendingItems.length} items will wait for connectivity');
    }
  }

  // ---------------------------------------------------------------------------
  //  Load / Save to SharedPreferences
  // ---------------------------------------------------------------------------
  Future<void> _loadQueuedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey) ?? [];

      debugPrint('📂 Loading active queue from SharedPreferences (${raw.length} elements)');
      _queuedProducts = [];
      
      for (final jsonString in raw) {
        try {
          final queuedProduct = QueuedProductModel.fromJson(jsonDecode(jsonString));
          // Only load if not completed
          if (queuedProduct.status != 'completed') {
            _queuedProducts.add(queuedProduct);
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing queued product: $e');
        }
      }

      _notify();
      debugPrint('✅ Active queue loaded successfully: ${_queuedProducts.length} items');
    } catch (e, st) {
      debugPrint('🚨 Error loading queue: $e\n$st');
      _queuedProducts = [];
      _notify();
    }
  }

  // Load completed products separately for permanent storage
  Future<void> _loadCompletedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_completedStorageKey) ?? [];

      debugPrint('📂 Loading completed products from SharedPreferences (${raw.length} elements)');
      
      for (final jsonString in raw) {
        try {
          final completedProduct = QueuedProductModel.fromJson(jsonDecode(jsonString));
          _queuedProducts.add(completedProduct);
        } catch (e) {
          debugPrint('⚠️ Error parsing completed product: $e');
        }
      }

      _notify();
      debugPrint('✅ Completed products loaded successfully');
    } catch (e, st) {
      debugPrint('🚨 Error loading completed products: $e\n$st');
    }
  }

  Future<void> _saveQueuedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save active queue (non-completed)
      final activeProducts = _queuedProducts.where((p) => p.status != 'completed').toList();
      final activeRaw = activeProducts.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_storageKey, activeRaw);
      
      // Save completed products separately for permanent storage
      final completedProducts = _queuedProducts.where((p) => p.status == 'completed').toList();
      final completedRaw = completedProducts.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_completedStorageKey, completedRaw);
      
      debugPrint('💾 Queue saved: ${activeRaw.length} active, ${completedRaw.length} completed');
    } catch (e) {
      debugPrint('🚨 Error saving queue: $e');
    }
  }

  void _notify() => _internalController.add(List.unmodifiable(_queuedProducts));

  // NUEVO: Limpieza periódica de imágenes huérfanas (solo para productos eliminados)
  Future<void> _periodicImageCleanup() async {
    debugPrint('🧹 Starting periodic image cleanup (preserving completed products)');
    
    // Solo considerar como "referenciadas" las imágenes de productos activos (no eliminados)
    final activeProducts = _queuedProducts.where((qp) => 
        qp.status == 'queued' || qp.status == 'uploading' || qp.status == 'failed' || qp.status == 'completed'
    ).toList();
    
    final referencedPaths = <String>[];
    for (final qp in activeProducts) {
      if (qp.product.pendingImagePaths?.isNotEmpty ?? false) {
        referencedPaths.addAll(qp.product.pendingImagePaths!);
      }
    }
    
    debugPrint('🔗 Preserving ${referencedPaths.length} images from ${activeProducts.length} active products');
    await _imageStorage.cleanupOrphanedImages(referencedPaths);
  }

  // MEJORADO: Agregar producto a la cola con mejor manejo de imágenes
  Future<String> addToQueue(ProductModel product) async {
    final id = const Uuid().v4();
    debugPrint('➕ Adding product to queue: ${product.title}');

    // CRÍTICO: Copiar imágenes a almacenamiento permanente
    List<String> permanentImagePaths = [];
    if (product.pendingImagePaths?.isNotEmpty ?? false) {
      debugPrint('📸 Processing ${product.pendingImagePaths!.length} images for permanent storage');
      
      for (final tempPath in product.pendingImagePaths!) {
        debugPrint('🔍 Checking temp image: $tempPath');
        final tempFile = File(tempPath);
        
        if (await tempFile.exists()) {
          final fileSize = await tempFile.length();
          debugPrint('✅ Temp image exists: $tempPath (${(fileSize / 1024).toInt()} KB)');
          
          // Copiar a almacenamiento permanente
          final permanentPath = await _imageStorage.saveImageToQueue(tempPath);
          if (permanentPath != null) {
            permanentImagePaths.add(permanentPath);
            debugPrint('✅ Image saved permanently: $permanentPath');
          } else {
            debugPrint('❌ Failed to save image permanently: $tempPath');
          }
        } else {
          debugPrint('❌ Temp image file not found: $tempPath');
        }
      }
      
      debugPrint('📦 Final permanent images: ${permanentImagePaths.length}/${product.pendingImagePaths!.length}');
    }

    // Create product with permanent image paths
    final updatedProduct = product.copyWith(
      pendingImagePaths: permanentImagePaths.isNotEmpty ? permanentImagePaths : null,
    );

    final qp = QueuedProductModel(
      queueId: id,
      product: updatedProduct,
      status: 'queued',
      queuedTime: DateTime.now(),
      statusMessage: permanentImagePaths.isNotEmpty 
          ? 'Product queued with ${permanentImagePaths.length} images'
          : 'Product queued (no images)',
    );
    
    _queuedProducts.add(qp);
    await _saveQueuedProducts();
    _notify();
    
    // AUTO-PROCESS if online
    _processIfOnline();
    debugPrint('✅ Product added to queue: ${product.title} with ${permanentImagePaths.length} images');

    return id;
  }

  // MEJORADO: Remover producto de la cola con limpieza de imágenes
  Future<void> removeFromQueue(String id) async {
    debugPrint('🗑️ Removing product from queue: $id');
    
    // Find the product to get its images
    final productIndex = _queuedProducts.indexWhere((p) => p.queueId == id);
    if (productIndex != -1) {
      final product = _queuedProducts[productIndex];
      
      // Delete associated images from permanent storage
      if (product.product.pendingImagePaths?.isNotEmpty ?? false) {
        debugPrint('🗑️ Deleting ${product.product.pendingImagePaths!.length} images from storage');
        await _imageStorage.deleteImages(product.product.pendingImagePaths!);
      }
      
      // Remove from queue
      _queuedProducts.removeAt(productIndex);
    } else {
      // Fallback: remove by ID if not found by index
      _queuedProducts.removeWhere((p) => p.queueId == id);
    }
    
    await _saveQueuedProducts();
    _notify();
    debugPrint('✅ Product removed from queue: $id');
  }

  Future<void> _cleanupOrphanedImages() async {
    // Solo hacer limpieza periódica, no en cada operación
    await _periodicImageCleanup();
  }

  Future<void> retryQueuedUpload(String id) async {
    debugPrint('🔄 Retrying product upload: $id');
    final idx = _queuedProducts.indexWhere((p) => p.queueId == id);
    if (idx == -1) {
      debugPrint('⚠️ Product not found in queue: $id');
      return;
    }

    _queuedProducts[idx] = _queuedProducts[idx].copyWith(
      status: 'queued',
      errorMessage: null,
      statusMessage: 'Retrying upload...',
    );

    await _saveQueuedProducts();
    _notify();
    debugPrint('✅ Product marked for retry: $id');
    _processIfOnline();
  }

Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      if (!await _connectivityService.checkConnectivity()) {
        _isProcessing = false;
        return;
      }

      final toUpload = _queuedProducts.where((qp) =>
        qp.status == 'queued' ||
        (qp.status == 'failed' && qp.retryCount < _maxRetries)
      ).toList();

      if (toUpload.isEmpty) {
        _isProcessing = false;
        return;
      }

      debugPrint('🌀 Procesando ${toUpload.length} productos en paralelo con isolates');
      // Crear tareas de isolate para cada producto
      final futures = toUpload.map((qp) {
        return compute(_uploadProductInIsolate, qp.toJson());
      }).toList();

      final results = await Future.wait<Map<String, dynamic>>(futures);

      for (var result in results) {
        final queueId = result['queueId'] as String;
        if (result['success'] == true) {
          await _updateStatus(queueId, 'completed', statusMessage: 'Upload completed successfully!');
        } else {
          await _updateStatus(
            queueId,
            'failed',
            error: result['error'] as String?,
            statusMessage: 'Upload failed. Tap to retry.',
          );
        }
      }

    } catch (e, st) {
      debugPrint('🚨 Error general en processQueue: $e\n$st');
    } finally {
      _isProcessing = false;
    }
  }

  static Future<Map<String, dynamic>> _uploadProductInIsolate(Map<String, dynamic> data) async {
    final qp = QueuedProductModel.fromJson(data);
    final dao = FirebaseDAO();
    try {
      final uploadedUrls = <String>[];
      for (final localPath in qp.product.pendingImagePaths ?? []) {
        final url = await dao.uploadProductImage(localPath).timeout(const Duration(seconds: 45));
        if (url == null || url.isEmpty) throw 'Error uploading image: $localPath';
        uploadedUrls.add(url);
      }

      final updatedProduct = qp.product.copyWith(
        imageUrls: [...qp.product.imageUrls, ...uploadedUrls],
        pendingImagePaths: [],
        updatedAt: DateTime.now(),
      );

      final newId = await dao.createProduct(updatedProduct.toMap()).timeout(const Duration(seconds: 20));
      if (newId == null || newId.isEmpty) throw 'Error creating product document';

      return {'queueId': qp.queueId, 'success': true};
    } catch (e) {
      return {'queueId': qp.queueId, 'success': false, 'error': e.toString()};
    }
  }



  // ---------------------------------------------------------------------------
  //  Auxiliares privados
  // ---------------------------------------------------------------------------
  Future<void> _updateStatus(String queueId, String status, {String? error, String? statusMessage}) async {
    final index = _queuedProducts.indexWhere((qp) => qp.queueId == queueId);
    if (index == -1) {
      debugPrint('⚠️ Product $queueId not found to update status');
      return;
    }

    debugPrint('🔄 Updating status of $queueId to "$status"${error != null ? " (error: $error)" : ""}');
    
    var qp = _queuedProducts[index].copyWith(
      status: status,
      queuedTime: status == 'completed' ? DateTime.now() : _queuedProducts[index].queuedTime,
      statusMessage: statusMessage
    );
    
    if (status == 'failed') {
      qp = qp.copyWith(
        retryCount: qp.retryCount + 1,
        errorMessage: error,
      );
    }

    _queuedProducts[index] = qp;
    await _saveQueuedProducts();
    _notify();
    debugPrint('✅ Status updated for $queueId: $status');
  }

  // NUEVO: Método para actualizar status con producto actualizado
  Future<void> _updateStatusWithProduct(String queueId, String status, ProductModel? updatedProduct, {String? error, String? statusMessage}) async {
    final index = _queuedProducts.indexWhere((qp) => qp.queueId == queueId);
    if (index == -1) {
      debugPrint('⚠️ Product $queueId not found to update status');
      return;
    }

    debugPrint('🔄 Updating status of $queueId to "$status"${error != null ? " (error: $error)" : ""}');
    
    var qp = _queuedProducts[index].copyWith(
      status: status,
      queuedTime: status == 'completed' ? DateTime.now() : _queuedProducts[index].queuedTime,
      statusMessage: statusMessage,
      // Actualizar el producto si se proporciona
      product: updatedProduct ?? _queuedProducts[index].product,
    );
    
    if (status == 'failed') {
      qp = qp.copyWith(
        retryCount: qp.retryCount + 1,
        errorMessage: error,
      );
    }

    _queuedProducts[index] = qp;
    await _saveQueuedProducts();
    _notify();
    debugPrint('✅ Status updated for $queueId: $status');
  }

  // MEJORADO: Validar y limpiar rutas de imágenes
  Future<void> _validateAndCleanupImagePaths() async {
    debugPrint('🔍 Validating image paths in queue...');
    bool hasChanges = false;
    
    for (int i = 0; i < _queuedProducts.length; i++) {
      final qp = _queuedProducts[i];
      final pendingPaths = qp.product.pendingImagePaths ?? [];
      
      if (pendingPaths.isNotEmpty) {
        debugPrint('🔍 Validating ${pendingPaths.length} images for product: ${qp.product.title}');
        
        // Check which images still exist
        final validPaths = <String>[];
        
        for (final path in pendingPaths) {
          final exists = await _imageStorage.imageExists(path);
          if (exists) {
            validPaths.add(path);
            debugPrint('✅ Image exists: $path');
          } else {
            debugPrint('❌ Image missing: $path');
            hasChanges = true;
          }
        }
        
        // If some images are missing, update the product
        if (validPaths.length != pendingPaths.length) {
          final updatedProduct = qp.product.copyWith(
            pendingImagePaths: validPaths.isEmpty ? null : validPaths,
          );
          
          String statusMessage;
          if (validPaths.isEmpty) {
            statusMessage = 'No images available - upload may fail';
          } else {
            statusMessage = '${validPaths.length}/${pendingPaths.length} images available';
          }
          
          _queuedProducts[i] = qp.copyWith(
            product: updatedProduct,
            statusMessage: statusMessage,
          );
          
          debugPrint('⚠️ Updated product ${qp.queueId}: ${validPaths.length}/${pendingPaths.length} images valid');
        }
      }
    }
    
    // Save changes if any paths were invalid
    if (hasChanges) {
      await _saveQueuedProducts();
      _notify();
      debugPrint('💾 Saved changes after image validation');
    } else {
      debugPrint('✅ All image paths validated successfully');
    }
  }

  // ---------------------------------------------------------------------------
  //  Limpieza
  // ---------------------------------------------------------------------------
  void dispose() {
    debugPrint('🧹 Cleaning up OfflineQueueService resources');
    _processingTimer?.cancel();
    _connectivitySubscription?.cancel();
    _internalController.close();
    _orderController.close();
    debugPrint('✅ OfflineQueueService cleaned up correctly');
  }

  // ---------------------------------------------------------------------------
  // Orders section
  // ---------------------------------------------------------------------------
  final _orderController = StreamController<List<QueuedOrderModel>>.broadcast();

  Stream<List<QueuedOrderModel>> get orderQueueStream => Stream.multi((controller) {
    controller.add(List.unmodifiable(_queuedOrders));
    final sub = _orderController.stream.listen(controller.add);
    controller.onCancel = () => sub.cancel();
  });

  List<QueuedOrderModel> get queuedOrders => List.unmodifiable(_queuedOrders);

  Future<String> addOrderToQueue(String orderID, String hashConfirm) async {
    final id = const Uuid().v4();
    debugPrint('Adding order to queue: $orderID');
    
    _queuedOrders.add(QueuedOrderModel(
      queueId: id,
      orderID: orderID,
      hashConfirm: hashConfirm,
      status: 'queued',
      queuedTime: DateTime.now(),
      retryCount: 0,
    ));
    
    await _saveOrders();
    _notifyOrders();
    _processIfOnline();
    return id;
  }

  Future<void> _saveOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _qrscanKey,
      _queuedOrders.map((o) => jsonEncode(o.toJson())).toList(),
    );
  }

  Future<void> _loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_qrscanKey) ?? [];
    _queuedOrders = raw.map((s) => QueuedOrderModel.fromJson(jsonDecode(s))).toList();
    _notifyOrders();
  }

  void _notifyOrders() => _orderController.add(List.unmodifiable(_queuedOrders));

  Future<void> processOrderQueue() async {
    if (_isProcessingOrders || !await _connectivityService.checkConnectivity()) {
      return;
    }
    
    _isProcessingOrders = true;
    try {
      final pending = _queuedOrders.where((o) => 
        o.status == 'queued' || 
        (o.status == 'failed' && o.retryCount < _maxRetries)
      ).toList();

      for (final order in pending) {
        await _updateOrderStatus(order.queueId, 'processing');
        
        try {
          await _firebaseDAO.updateOrderStatus(
            order.orderID, 
            'Delivered'
          ).timeout(const Duration(seconds: 20));
          
          await _updateOrderStatus(order.queueId, 'completed');
        } catch (e) {
          await _updateOrderStatus(
            order.queueId, 
            'failed', 
            error: e.toString()
          );
        }
      }
    } finally {
      _isProcessingOrders = false;
    }
  }

  Future<void> forceCleanupOrphanedImages() async {
    await _cleanupOrphanedImages();
  }

  Future<Map<String, dynamic>> getStorageStats() async {
    final totalSize = await _imageStorage.getTotalQueueImagesSize();
    final referencedPaths = <String>[];
    
    for (final qp in _queuedProducts) {
      if (qp.product.pendingImagePaths?.isNotEmpty ?? false) {
        referencedPaths.addAll(qp.product.pendingImagePaths!);
      }
    }
    
    return {
      'totalImages': referencedPaths.length,
      'totalSizeBytes': totalSize,
      'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      'queueDirectoryPath': _imageStorage.queueDirectoryPath,
    };
  }

  Future<void> _updateOrderStatus(String id, String status, {String? error}) async {
    final index = _queuedOrders.indexWhere((o) => o.queueId == id);
    if (index == -1) return;
    
    var updated = _queuedOrders[index].copyWith(status: status);
    if (status == 'failed') {
      updated = updated.copyWith(
        retryCount: updated.retryCount + 1,
        errorMessage: error,
      );
    }
    
    _queuedOrders[index] = updated;
    await _saveOrders();
    _notifyOrders();
  }
}