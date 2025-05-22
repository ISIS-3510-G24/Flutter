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
  static const String _qrscanKey = 'product_delivery_queue';
  static const int _maxRetries = 3;
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _uploadTimeout = Duration(seconds: 20);

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
  // ---------------------------------------------------------------------------
  Future<void> initialize() async {
    debugPrint('🔧 Initializing OfflineQueueService');
    try {
      await _loadQueuedProducts();
      await _loadOrders();
      debugPrint('📦 Loaded ${_queuedProducts.length} products in queue');
      
      // Immediate cleanup of old completed items
      await _cleanupCompletedItems();
      
      _connectivitySubscription?.cancel();
      _connectivitySubscription = _connectivityService.connectivityStream.listen(_onConnectivityChange);
      debugPrint('🔌 Connectivity listener configured');
      
      _setupPeriodicCheck();
      debugPrint('⏰ Periodic check configured');
      
      // Only process if we have reliable connection
      _processIfOnlineReliable();
      
      debugPrint('✅ OfflineQueueService initialized correctly');
    } catch (e, st) {
      debugPrint('🚨 Error initializing OfflineQueueService: $e\n$st');
      _queuedProducts = [];
      _notify();
    }
  }

  void _setupPeriodicCheck() {
    _processingTimer?.cancel();
    _processingTimer =
        Timer.periodic(const Duration(minutes: 10), (_) => _processIfOnlineReliable());
    debugPrint('⏱️ Verification timer configured (every 10 min)');
  }

  void _onConnectivityChange(bool hasInternet) {
    debugPrint('🔌 Connectivity change detected: $hasInternet');
    
    if (hasInternet) {
      // Wait longer to ensure stable connection
      Future.delayed(const Duration(seconds: 5), () async {
        if (await _isConnectionReliable()) {
          debugPrint('🔌 Stable connection confirmed, processing queue...');
          processQueue();
          processOrderQueue();
        } else {
          debugPrint('🔌 Connection not stable enough for upload');
        }
      });
    }
  }

  // Better connection reliability check
  Future<bool> _isConnectionReliable() async {
    try {
      debugPrint('🔍 Testing connection reliability...');
      
      // First check basic connectivity
      if (!await _connectivityService.checkConnectivity()) {
        debugPrint('❌ Basic connectivity check failed');
        return false;
      }

      // Test actual network access with timeout
      final result = await InternetAddress.lookup('google.com')
          .timeout(_connectionTimeout);
      
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        debugPrint('✅ Connection is reliable');
        return true;
      } else {
        debugPrint('❌ DNS lookup failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      return false;
    }
  }

  Future<void> _processIfOnlineReliable() async {
    debugPrint('🔍 Checking reliable connectivity for processing...');
    if (await _isConnectionReliable()) {
      debugPrint('✅ Reliable connection available, processing queue');
      processQueue();
      processOrderQueue();
    } else {
      debugPrint('❌ No reliable connection, skipping upload');
    }
  }

  // ---------------------------------------------------------------------------
  //  Load / Save to SharedPreferences
  // ---------------------------------------------------------------------------
  Future<void> _loadQueuedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey) ?? [];

      debugPrint('📂 Loading queue from SharedPreferences (${raw.length} elements)');
      _queuedProducts = raw
          .map((s) => QueuedProductModel.fromJson(jsonDecode(s)))
          .toList();

      _queuedProducts.forEach((p) => 
        debugPrint('Loaded from storage - Product ${p.queueId}: ${p.status} (${p.queuedTime})')
      );

      _notify();
      debugPrint('✅ Queue loaded successfully from persistent storage');
    } catch (e, st) {
      debugPrint('🚨 Error loading queue: $e\n$st');
      _queuedProducts = [];
      _notify();
    }
  }

  Future<void> _saveQueuedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _queuedProducts.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_storageKey, raw);
      debugPrint('💾 Queue saved to SharedPreferences (${raw.length} elements)');
    } catch (e) {
      debugPrint('🚨 Error saving queue: $e');
    }
  }

  // ---------------------------------------------------------------------------
  //  Public API
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
    
    debugPrint('✅ Product added to queue: ${product.title}');

    // Only try to process if we have a reliable connection
    // Don't block the UI waiting for this
    _processIfOnlineReliable();

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
      statusMessage: 'Queued for retry...',
    );

    await _saveQueuedProducts();
    _notify();
    debugPrint('✅ Product marked for retry: $id');
    
    // Only try to process if connection is reliable
    _processIfOnlineReliable();
  }

  Future<void> processQueue() async {
    if (_isProcessing) {
      debugPrint('⚠️ Processing already in progress, aborting');
      return;
    }
    
    debugPrint('🔄 Starting queue processing');
    _isProcessing = true;

    try {
      // Double-check connection reliability before processing
      if (!await _isConnectionReliable()) {
        debugPrint('📵 No reliable connection, aborting processing');
        _isProcessing = false;
        return;
      }

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

      for (final qp in toUpload) {
        debugPrint('⬆️ Processing product: ${qp.product.title}');
        
        // Re-check connection before each upload
        if (!await _isConnectionReliable()) {
          debugPrint('⚠️ Lost connection during processing');
          break;
        }

        await _updateStatus(qp.queueId, 'uploading', statusMessage: 'Preparing upload...');

        try {
          // Upload images with shorter timeout and better error handling
          final uploaded = <String>[];
          final pendingPaths = qp.product.pendingImagePaths ?? [];
          
          debugPrint('🖼️ Uploading ${pendingPaths.length} images');
          await _updateStatus(qp.queueId, 'uploading', statusMessage: 'Uploading images...');
          
          for (var i = 0; i < pendingPaths.length; i++) {
            final local = pendingPaths[i];
            final file = File(local);
            
            if (!await file.exists()) {
              debugPrint('⚠️ File not found: $local');
              throw 'Image file not found';
            }
            
            // Check connection before each image upload
            if (!await _isConnectionReliable()) {
              throw 'Connection lost during upload';
            }
            
            String? url;
            try {
              await _updateStatus(qp.queueId, 'uploading', 
                statusMessage: 'Uploading image ${i + 1} of ${pendingPaths.length}...');
                
              url = await _firebaseDAO.uploadProductImage(local)
                  .timeout(_uploadTimeout);
                  
            } catch (e) {
              debugPrint('⚠️ Error uploading image: $e');
              throw 'Failed to upload image: ${e.toString()}';
            }
            
            if (url != null && url.isNotEmpty) {
              uploaded.add(url);
              debugPrint('✅ Image uploaded: $url');
            } else {
              throw 'Image upload returned empty URL';
            }
          }

          // Create product document
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
                .timeout(_uploadTimeout);
          } catch (e) {
            debugPrint('⚠️ Error creating product: $e');
            throw 'Failed to save product: ${e.toString()}';
          }
          
          if (newId == null || newId.isEmpty) {
            throw 'Product creation returned empty ID';
          }

          debugPrint('✅ Product created successfully: ${qp.product.title}');
          await _updateStatus(qp.queueId, 'completed', statusMessage: 'Upload completed!');
          
          // Auto-cleanup completed item after a short delay
          Future.delayed(const Duration(seconds: 3), () async {
            await _removeCompletedItem(qp.queueId);
          });
          
        } catch (e) {
          debugPrint('❌ Error processing product ${qp.product.title}: $e');
          String errorMessage = e.toString();
          
          // Simplify error messages for user
          if (errorMessage.contains('TimeoutException')) {
            errorMessage = 'Upload timeout - check connection';
          } else if (errorMessage.contains('Connection lost')) {
            errorMessage = 'Connection lost during upload';
          } else if (errorMessage.contains('unavailable')) {
            errorMessage = 'Service temporarily unavailable';
          }
          
          await _updateStatus(
            qp.queueId,
            'failed',
            error: errorMessage,
            statusMessage: 'Upload failed - tap to retry'
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

  Future<void> removeCompletedItems() async {
    await _cleanupCompletedItems();
  }

  // ---------------------------------------------------------------------------
  //  Private helpers
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

  // Remove a specific completed item
  Future<void> _removeCompletedItem(String queueId) async {
    final index = _queuedProducts.indexWhere((p) => p.queueId == queueId && p.status == 'completed');
    if (index != -1) {
      _queuedProducts.removeAt(index);
      await _saveQueuedProducts();
      _notify();
      debugPrint('🧹 Removed completed item: $queueId');
    }
  }

  // Cleanup old completed items
  Future<void> _cleanupCompletedItems() async {
    debugPrint('🧹 Cleaning up completed items');
    
    final now = DateTime.now();
    final initialCount = _queuedProducts.length;
    
    // Remove completed items older than 30 minutes
    _queuedProducts.removeWhere((p) => 
      p.status == 'completed' && 
      now.difference(p.queuedTime).inMinutes >= 30
    );
    
    final removedCount = initialCount - _queuedProducts.length;
    if (removedCount > 0) {
      await _saveQueuedProducts();
      _notify();
      debugPrint('🧹 Removed $removedCount completed items');
    }
  }

  // ---------------------------------------------------------------------------
  //  Cleanup
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
    _processIfOnlineReliable();
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
    if (_isProcessingOrders || !await _isConnectionReliable()) {
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
          ).timeout(_uploadTimeout);
          
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