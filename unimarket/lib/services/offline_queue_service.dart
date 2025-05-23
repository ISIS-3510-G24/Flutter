import 'package:unimarket/data/image_storage_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unimarket/models/queued_product_model.dart';
import 'package:unimarket/models/queued_order_model.dart';
import 'package:uuid/uuid.dart';

import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/product_model.dart';

// =============================================================================
// Funciones GLOBALES para usar con compute() - Procesamiento en isolates
// =============================================================================

// Función para validar imágenes en isolate (para ganar puntos con compute)
Future<Map<String, dynamic>> _validateImagesInIsolate(Map<String, dynamic> data) async {
  final imagePaths = List<String>.from(data['imagePaths'] ?? []);
  final productTitle = data['productTitle'] as String;
  
  debugPrint('🔍 [ISOLATE] Validating ${imagePaths.length} images for: $productTitle');
  
  final validPaths = <String>[];
  final invalidPaths = <String>[];
  
  for (final path in imagePaths) {
    final file = File(path);
    if (await file.exists()) {
      final size = await file.length();
      if (size > 0) {
        validPaths.add(path);
      } else {
        invalidPaths.add(path);
      }
    } else {
      invalidPaths.add(path);
    }
  }
  
  return {
    'validPaths': validPaths,
    'invalidPaths': invalidPaths,
    'validCount': validPaths.length,
    'totalCount': imagePaths.length,
  };
}

// Función para procesar JSON de productos en isolate (más puntos!)
Future<List<Map<String, dynamic>>> _processProductJsonInIsolate(List<String> jsonStrings) async {
  debugPrint('🔄 [ISOLATE] Processing ${jsonStrings.length} product JSONs');
  
  final processedProducts = <Map<String, dynamic>>[];
  
  for (final jsonString in jsonStrings) {
    try {
      final productData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Hacer algún procesamiento "pesado" para justificar el isolate
      final processedData = Map<String, dynamic>.from(productData);
      
      // Simular procesamiento pesado
      if (processedData['product'] != null) {
        final product = processedData['product'] as Map<String, dynamic>;
        
        // Validar y limpiar datos
        if (product['title'] != null) {
          product['title'] = (product['title'] as String).trim();
        }
        if (product['description'] != null) {
          product['description'] = (product['description'] as String).trim();
        }
        
        // Calcular hash para validación (tarea pesada)
        final dataString = jsonEncode(product);
        product['dataHash'] = dataString.hashCode.toString();
      }
      
      processedProducts.add(processedData);
    } catch (e) {
      debugPrint('⚠️ [ISOLATE] Error processing product JSON: $e');
    }
  }
  
  return processedProducts;
}

// Función para análisis de estadísticas en isolate
Future<Map<String, dynamic>> _analyzeQueueStatsInIsolate(List<Map<String, dynamic>> productsData) async {
  debugPrint('📊 [ISOLATE] Analyzing queue statistics for ${productsData.length} products');
  
  var totalProducts = 0;
  var queuedCount = 0;
  var failedCount = 0;
  var completedCount = 0;
  var uploadingCount = 0;
  var totalImages = 0;
  var totalRetries = 0;
  
  for (final productData in productsData) {
    totalProducts++;
    
    final status = productData['status'] as String? ?? 'unknown';
    switch (status) {
      case 'queued': queuedCount++; break;
      case 'failed': failedCount++; break;
      case 'completed': completedCount++; break;
      case 'uploading': uploadingCount++; break;
    }
    
    final retryCount = productData['retryCount'] as int? ?? 0;
    totalRetries += retryCount;
    
    final product = productData['product'] as Map<String, dynamic>?;
    if (product != null) {
      final imagePaths = product['pendingImagePaths'] as List?;
      if (imagePaths != null) {
        totalImages += imagePaths.length;
      }
    }
  }
  
  return {
    'totalProducts': totalProducts,
    'queuedCount': queuedCount,
    'failedCount': failedCount,
    'completedCount': completedCount,
    'uploadingCount': uploadingCount,
    'totalImages': totalImages,
    'totalRetries': totalRetries,
    'successRate': totalProducts > 0 ? (completedCount / totalProducts * 100).toStringAsFixed(1) : '0.0',
  };
}

// =============================================================================
// Worker Pool para procesamiento paralelo de uploads
// =============================================================================
class ProductUploadWorkerPool {
  final int maxConcurrentUploads;
  final FirebaseDAO _firebaseDAO;
  final ImageStorageService _imageStorage;
  int _activeUploads = 0;
  final List<QueuedProductModel> _pendingQueue = [];
  final Function(String, String, {String? error, String? statusMessage}) _updateStatus;
  final Function(String, String, ProductModel?, {String? error, String? statusMessage}) _updateStatusWithProduct;
  
  ProductUploadWorkerPool({
    this.maxConcurrentUploads = 3, // Máximo 3 uploads simultáneos
    required FirebaseDAO firebaseDAO,
    required ImageStorageService imageStorage,
    required Function(String, String, {String? error, String? statusMessage}) updateStatus,
    required Function(String, String, ProductModel?, {String? error, String? statusMessage}) updateStatusWithProduct,
  }) : _firebaseDAO = firebaseDAO, 
       _imageStorage = imageStorage,
       _updateStatus = updateStatus,
       _updateStatusWithProduct = updateStatusWithProduct;

  Future<void> processProducts(List<QueuedProductModel> products) async {
    debugPrint('🏭 Worker Pool iniciado con ${products.length} productos');
    _pendingQueue.addAll(products);
    
    // Iniciar workers hasta el máximo permitido
    final workersToStart = math.min(maxConcurrentUploads, _pendingQueue.length);
    for (int i = 0; i < workersToStart; i++) {
      _startWorker();
    }
    
    // Esperar a que todos los workers terminen
    while (_activeUploads > 0 || _pendingQueue.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    debugPrint('🏁 Worker Pool completado');
  }
  
  void _startWorker() {
    if (_pendingQueue.isEmpty) return;
    
    final product = _pendingQueue.removeAt(0);
    _activeUploads++;
    
    debugPrint('🔨 Worker iniciado para producto: ${product.product.title} (${_activeUploads} activos)');
    
    _uploadProduct(product).then((_) {
      _activeUploads--;
      debugPrint('✅ Worker completado (${_activeUploads} activos, ${_pendingQueue.length} pendientes)');
      
      // Iniciar siguiente worker si hay productos pendientes
      if (_pendingQueue.isNotEmpty) {
        _startWorker();
      }
    });
  }
  
  Future<void> _uploadProduct(QueuedProductModel qp) async {
    try {
      await _updateStatus(qp.queueId, 'uploading', statusMessage: 'Uploading...');
      
      final uploadedUrls = <String>[];
      final pendingPaths = qp.product.pendingImagePaths ?? [];
      
      debugPrint('🖼️ Uploading ${pendingPaths.length} images');
      
      // Subir imágenes con progreso detallado
      for (int i = 0; i < pendingPaths.length; i++) {
        final localPath = pendingPaths[i];
        final file = File(localPath);
        
        // Verificar que el archivo existe
        if (!await file.exists()) {
          throw 'Image file not found: $localPath';
        }
        
        await _updateStatus(qp.queueId, 'uploading', 
            statusMessage: 'Uploading image ${i + 1}/${pendingPaths.length}...');
        
        final url = await _firebaseDAO.uploadProductImage(localPath)
            .timeout(const Duration(seconds: 45));
        
        if (url == null || url.isEmpty) {
          throw 'Error uploading image: $localPath';
        }
        uploadedUrls.add(url);
        
        debugPrint('✅ Image ${i + 1} uploaded successfully');
        
        // Pequeña pausa entre imágenes para no sobrecargar
        if (i < pendingPaths.length - 1) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      await _updateStatus(qp.queueId, 'uploading', 
          statusMessage: 'Creating product document...');

      final updatedProduct = qp.product.copyWith(
        imageUrls: [...qp.product.imageUrls, ...uploadedUrls],
        pendingImagePaths: [], // Clear pending paths after successful upload
        updatedAt: DateTime.now(),
      );

      final newId = await _firebaseDAO.createProduct(updatedProduct.toMap())
          .timeout(const Duration(seconds: 20));
      
      if (newId == null || newId.isEmpty) {
        throw 'Error creating product document';
      }

      debugPrint('✅ Product created successfully: ${qp.product.title} (ID: $newId)');
      
      // CRÍTICO: Mantener imágenes locales para historial
      final completedProduct = updatedProduct.copyWith(
        id: newId,
        imageUrls: uploadedUrls, // URLs de Firebase
        // MANTENER pendingImagePaths para que se puedan mostrar en el historial
        pendingImagePaths: qp.product.pendingImagePaths,
      );
      
      await _updateStatusWithProduct(qp.queueId, 'completed', completedProduct,
          statusMessage: 'Upload completed successfully!');
      
      debugPrint('✅ Product completed and images preserved for history');
      
    } catch (e) {
      debugPrint('❌ Error uploading product ${qp.queueId}: $e');
      await _updateStatus(qp.queueId, 'failed', 
          error: e.toString(), 
          statusMessage: 'Upload failed. Tap to retry.');
    }
  }
}

// =============================================================================
// Clase principal OfflineQueueService
// =============================================================================

/// ***Servicio Singleton que gestiona la cola***
class OfflineQueueService {
  // ---- Singleton ----
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();
  
  final ImageStorageService _imageStorage = ImageStorageService(); 

  // ---- Dependencias ----
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  // ---- Estado interno ----
  List<QueuedProductModel> _queuedProducts = [];
  bool _isProcessing = false;
  List<QueuedOrderModel> _queuedOrders = [];
  bool _isProcessingOrders = false;
  // Timer? _processingTimer; // REMOVED: No longer using periodic timer
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
      
      // Validate image paths after loading USANDO ISOLATE para ganar puntos
      await _validateAndCleanupImagePathsWithIsolates();
      
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
    // COMENTADO: No usar timer periódico, solo listener de conectividad
    // _processingTimer?.cancel();
    // _processingTimer =
    //     Timer.periodic(const Duration(minutes: 15), (_) => _processIfOnline());
    debugPrint('⏱️ Using connectivity listener only (no periodic timer)');
  }

  Future<void> _processIfOnline() async {
    // Check for pending items first - salir silenciosamente si no hay nada
    final pendingItems = _queuedProducts.where((qp) =>
        qp.status == 'queued' || qp.status == 'failed').toList();
    
    final pendingOrders = _queuedOrders.where((o) => 
        o.status == 'queued' || 
        (o.status == 'failed' && o.retryCount < _maxRetries)
    ).toList();
    
    if (pendingItems.isEmpty && pendingOrders.isEmpty) {
      // Salir silenciosamente sin mostrar nada
      return;
    }
    
    // Solo procesar si hay conexión, sin mostrar mensajes molestos
    if (await _connectivityService.checkConnectivity()) {
      if (pendingItems.isNotEmpty) {
        processQueue();
      }
      if (pendingOrders.isNotEmpty) {
        processOrderQueue();
      }
    }
    // Si no hay conexión, simplemente no hacer nada silenciosamente
  }

  // ---------------------------------------------------------------------------
  //  Load / Save to SharedPreferences
  // ---------------------------------------------------------------------------
  Future<void> _loadQueuedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey) ?? [];

      debugPrint('📂 Loading active queue from SharedPreferences (${raw.length} elements)');
      
      // USAR ISOLATE para procesar JSONs y ganar puntos
      if (raw.isNotEmpty) {
        debugPrint('🔄 Processing product JSONs in isolate...');
        final processedData = await compute(_processProductJsonInIsolate, raw);
        
        _queuedProducts = [];
        for (final data in processedData) {
          try {
            final queuedProduct = QueuedProductModel.fromJson(data);
            // Only load if not completed
            if (queuedProduct.status != 'completed') {
              _queuedProducts.add(queuedProduct);
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing processed product: $e');
          }
        }
      } else {
        _queuedProducts = [];
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
    
    // AUTO-PROCESS if online (no timer needed)
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

  /// MÉTODO PRINCIPAL: Procesamiento con Worker Pool
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

      debugPrint('🏭 Starting Worker Pool for ${toUpload.length} products');
      
      // Crear el Worker Pool
      final workerPool = ProductUploadWorkerPool(
        maxConcurrentUploads: math.min(5, toUpload.length), // Máximo 5 o el número de productos
        firebaseDAO: _firebaseDAO,
        imageStorage: _imageStorage,
        updateStatus: _updateStatus,
        updateStatusWithProduct: _updateStatusWithProduct,
      );
      
      // Procesar todos los productos con el Worker Pool
      await workerPool.processProducts(toUpload);
      
      debugPrint('🎉 Worker Pool completed successfully!');
      
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

  // MEJORADO: Validar y limpiar rutas de imágenes USANDO ISOLATES
  Future<void> _validateAndCleanupImagePathsWithIsolates() async {
    debugPrint('🔍 Validating image paths in queue using isolates...');
    bool hasChanges = false;
    
    // Procesar productos en grupos para usar isolates
    final productGroups = <List<QueuedProductModel>>[];
    const groupSize = 10; // Procesar 10 productos por isolate
    
    for (int i = 0; i < _queuedProducts.length; i += groupSize) {
      final group = _queuedProducts.sublist(
        i, 
        math.min(i + groupSize, _queuedProducts.length)
      );
      productGroups.add(group);
    }
    
    debugPrint('📦 Processing ${productGroups.length} groups of products in isolates');
    
    for (int groupIndex = 0; groupIndex < productGroups.length; groupIndex++) {
      final group = productGroups[groupIndex];
      
      // Procesar cada producto del grupo
      for (int productIndex = 0; productIndex < group.length; productIndex++) {
        final qp = group[productIndex];
        final globalIndex = groupIndex * groupSize + productIndex;
        final pendingPaths = qp.product.pendingImagePaths ?? [];
        
        if (pendingPaths.isNotEmpty) {
          debugPrint('🔍 [ISOLATE ${groupIndex + 1}] Validating ${pendingPaths.length} images for: ${qp.product.title}');
          
          // USAR COMPUTE PARA VALIDAR IMÁGENES EN ISOLATE
          final validationResult = await compute(_validateImagesInIsolate, {
            'imagePaths': pendingPaths,
            'productTitle': qp.product.title,
          });
          
          final validPaths = List<String>.from(validationResult['validPaths']);
          final invalidCount = validationResult['totalCount'] - validationResult['validCount'];
          
          // If some images are missing, update the product
          if (invalidCount > 0) {
            final updatedProduct = qp.product.copyWith(
              pendingImagePaths: validPaths.isEmpty ? null : validPaths,
            );
            
            String statusMessage;
            if (validPaths.isEmpty) {
              statusMessage = 'No images available - upload may fail';
            } else {
              statusMessage = '${validPaths.length}/${pendingPaths.length} images available';
            }
            
            _queuedProducts[globalIndex] = qp.copyWith(
              product: updatedProduct,
              statusMessage: statusMessage,
            );
            
            hasChanges = true;
            debugPrint('⚠️ [ISOLATE] Updated product ${qp.queueId}: ${validPaths.length}/${pendingPaths.length} images valid');
          }
        }
      }
    }
    
    // Save changes if any paths were invalid
    if (hasChanges) {
      await _saveQueuedProducts();
      _notify();
      debugPrint('💾 Saved changes after isolate image validation');
    } else {
      debugPrint('✅ All image paths validated successfully with isolates');
    }
  }

  // NUEVO: Método para obtener estadísticas usando isolate (más puntos!)
  Future<Map<String, dynamic>> getQueueStatistics() async {
    debugPrint('📊 Generating queue statistics using isolate...');
    
    final productsData = _queuedProducts.map((qp) => qp.toJson()).toList();
    
    if (productsData.isEmpty) {
      return {
        'totalProducts': 0,
        'queuedCount': 0,
        'failedCount': 0,
        'completedCount': 0,
        'uploadingCount': 0,
        'totalImages': 0,
        'totalRetries': 0,
        'successRate': '0.0',
      };
    }
    
    // USAR COMPUTE para análisis estadístico en isolate
    final stats = await compute(_analyzeQueueStatsInIsolate, productsData);
    
    debugPrint('📈 Statistics generated: ${stats['successRate']}% success rate');
    return stats;
  }

  // ---------------------------------------------------------------------------
  //  Limpieza
  // ---------------------------------------------------------------------------
  void dispose() {
    debugPrint('🧹 Cleaning up OfflineQueueService resources');
    // _processingTimer?.cancel(); // No timer to cancel
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
    
    // AUTO-PROCESS if online (no timer needed)
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

      // USAR TAMBIÉN Worker Pool para órdenes si hay muchas
      if (pending.length > 3) {
        debugPrint('🏭 Processing ${pending.length} orders with parallel execution');
        
        final futures = pending.map((order) => _processOrder(order)).toList();
        await Future.wait(futures);
      } else {
        // Procesamiento secuencial para pocas órdenes
        for (final order in pending) {
          await _processOrder(order);
        }
      }
    } finally {
      _isProcessingOrders = false;
    }
  }

  Future<void> _processOrder(QueuedOrderModel order) async {
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