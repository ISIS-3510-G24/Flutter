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

/// ***Servicio Singleton que gestiona la cola***
class OfflineQueueService {
  // ---- Singleton ----
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  // ---- Dependencias ----
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  // ---- Estado interno ----
  List<QueuedProductModel> _queuedProducts = [];
  bool _isProcessing = false;
  List<QueuedOrderModel> _queuedOrders = [];
  bool _isProcessingOrders = false;
  Timer? _processingTimer;
  StreamSubscription? _connectivitySubscription;

  // ---- Constantes ----
  static const String _storageKey = 'offline_product_queue';
  static const String _completedStorageKey = 'completed_product_history'; // NEW: separate storage for completed
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

  // ---------------------------------------------------------------------------
  // Inicialización
Future<void> initialize() async {
  debugPrint('🔧 Initializing OfflineQueueService');
  try {
    await _loadQueuedProducts();
    await _loadCompletedProducts();
    await _loadOrders();
    
    // NEW: Validate image paths after loading
    await _validateAndCleanupImagePaths();
    
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
      _queuedProducts = raw
          .map((s) => QueuedProductModel.fromJson(jsonDecode(s)))
          .where((p) => p.status != 'completed') // Don't load completed here
          .toList();

      _notify();
      debugPrint('✅ Active queue loaded successfully');
    } catch (e, st) {
      debugPrint('🚨 Error loading queue: $e\n$st');
      _queuedProducts = [];
      _notify();
    }
  }

  // NEW: Load completed products separately for permanent storage
  Future<void> _loadCompletedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_completedStorageKey) ?? [];

      debugPrint('📂 Loading completed products from SharedPreferences (${raw.length} elements)');
      final completedProducts = raw
          .map((s) => QueuedProductModel.fromJson(jsonDecode(s)))
          .toList();

      // Add completed products to main list
      _queuedProducts.addAll(completedProducts);
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

  // ---------------------------------------------------------------------------
  //  API pública
  // ---------------------------------------------------------------------------
  Future<String> addToQueue(ProductModel product) async {
    final id = const Uuid().v4();
    debugPrint('➕ Adding product to queue: ${product.title}');

    final qp = QueuedProductModel(
      queueId: id,
      product: product,
      status: 'queued',
      queuedTime: DateTime.now(),
      statusMessage: 'Product saved to queue',
    );
    _queuedProducts.add(qp);
    await _saveQueuedProducts();
    _notify();
    
    // AUTO-PROCESS if online
    _processIfOnline();
    debugPrint('✅ Product added to queue: ${product.title}');

    return id;
  }

  Future<void> removeFromQueue(String id) async {
    debugPrint('🗑️ Removing product from queue: $id');
    _queuedProducts.removeWhere((p) => p.queueId == id);
    await _saveQueuedProducts();
    _notify();
    debugPrint('✅ Product removed from queue: $id');
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

  /// Procesa toda la cola (si no se está procesando ya).
  Future<void> processQueue() async {
    if (_isProcessing) {
      debugPrint('⚠️ Processing already in progress, aborting');
      return;
    }
    
    debugPrint('🔄 Starting queue processing');
    _isProcessing = true;

    try {
      // Verificar conectividad primero
      if (!await _connectivityService.checkConnectivity()) {
        debugPrint('📵 No connection, aborting processing');
        _isProcessing = false;
        return;
      }

      // Obtener productos para subir
      final toUpload = _queuedProducts.where((qp) =>
              qp.status == 'queued' ||
              (qp.status == 'failed' && qp.retryCount < _maxRetries))
          .toList();

      debugPrint('📋 Products to process: ${toUpload.length}');
      
      if (toUpload.isEmpty) {
        debugPrint('✅ No products to process');
        _isProcessing = false;
        return;
      }

      // Procesar cada producto
      for (final qp in toUpload) {
        debugPrint('⬆️ Processing product: ${qp.product.title}');
        await _updateStatus(qp.queueId, 'uploading', statusMessage: 'Preparing upload...');

        try {
          // ------------------- 1. subir imágenes -------------------
          final uploaded = <String>[];
          final pendingPaths = qp.product.pendingImagePaths ?? [];
          
          debugPrint('🖼️ Uploading ${pendingPaths.length} images');
          await _updateStatus(qp.queueId, 'uploading', statusMessage: 'Uploading images...');
          
          for (var i = 0; i < pendingPaths.length; i++) {
            final local = pendingPaths[i];
            final file = File(local);
            if (!await file.exists()) {
              debugPrint('⚠️ File not found: $local');
              throw 'File not found: $local';
            }
            
            String? url;
            try {
              await _updateStatus(qp.queueId, 'uploading', statusMessage: 'Uploading image ${i + 1}/${pendingPaths.length}...');
              url = await _firebaseDAO.uploadProductImage(local)
                  .timeout(const Duration(seconds: 30));
            } catch (e) {
              debugPrint('⚠️ Error uploading image: $e');
              throw 'Error uploading image: $e';
            }
            
            if (url != null) {
              uploaded.add(url);
              debugPrint('✅ Image uploaded: $url');
            } else {
              debugPrint('⚠️ Null URL when uploading $local');
              throw 'Error uploading $local: Null URL';
            }
          }

          // ------------------- 2. crear documento -------------------
          debugPrint('📄 Creating product document');
          await _updateStatus(qp.queueId, 'uploading', statusMessage: 'Saving product...');
          
          final updatedProduct = qp.product.copyWith(
            imageUrls: [...qp.product.imageUrls, ...uploaded],
            pendingImagePaths: [],
            updatedAt: DateTime.now(),
          );
          
          String? newId;
          try {
            newId = await _firebaseDAO.createProduct(updatedProduct.toMap())
                .timeout(const Duration(seconds: 20));
          } catch (e) {
            debugPrint('⚠️ Error creating product: $e');
            throw 'Error creating product: $e';
          }
          
          if (newId == null) {
            debugPrint('⚠️ Null ID when creating product');
            throw 'createProduct returned null';
          }

          debugPrint('✅ Product created: ${qp.product.title}');
          await _updateStatus(qp.queueId, 'completed', statusMessage: 'Upload completed successfully!');
          
        } catch (e) {
          debugPrint('❌ Error processing product ${qp.product.title}: $e');
          await _updateStatus(
            qp.queueId,
            'failed',
            error: e.toString(),
            statusMessage: 'Upload failed. Tap to retry.'
          );
        }
      }
      
      debugPrint('✅ Queue processing completed');
      
    } catch (e, st) {
      debugPrint('🚨 General error in processQueue: $e\n$st');
    } finally {
      _isProcessing = false;
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

  void _notify() => _internalController.add(List.unmodifiable(_queuedProducts));

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

Future<void> _validateAndCleanupImagePaths() async {
  debugPrint('🔍 Validating image paths in queue...');
  bool hasChanges = false;
  
  for (int i = 0; i < _queuedProducts.length; i++) {
    final qp = _queuedProducts[i];
    final pendingPaths = qp.product.pendingImagePaths ?? [];
    
    if (pendingPaths.isNotEmpty) {
      // Check which images still exist
      final validPaths = <String>[];
      
      for (final path in pendingPaths) {
        final file = File(path);
        if (await file.exists()) {
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
        
        _queuedProducts[i] = qp.copyWith(
          product: updatedProduct,
          statusMessage: validPaths.isEmpty 
              ? 'Images missing - product may fail to upload'
              : 'Some images missing',
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
  }
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