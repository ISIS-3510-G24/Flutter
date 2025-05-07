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
  // Añadimos la variable de suscripción para manejar los listeners
  StreamSubscription? _connectivitySubscription;

  // ---- Constantes ----
  static const String _storageKey = 'offline_product_queue';
  static const String _qrscanKey = 'product_delivery_queue';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(minutes: 5);

  // ---- **** Stream **** ----
  // 1) Este controller solo emite *cambios* posteriores
  final _internalController =
      StreamController<List<QueuedProductModel>>.broadcast();


  // 2) Este getter emite el snapshot actual **y** luego sigue
  Stream<List<QueuedProductModel>> get queueStream =>
      Stream.multi((controller) {
        // snapshot inmediato — soluciona el "no se ve nada" estando offline
        controller.add(List.unmodifiable(_queuedProducts));

        // subsiguientes cambios
        final sub = _internalController.stream.listen(controller.add);
        controller.onCancel = () => sub.cancel();
      });

  // 3) Getter síncrono para usar como `initialData`
  List<QueuedProductModel> get queuedProducts =>
      List.unmodifiable(_queuedProducts);

  // ---------------------------------------------------------------------------
  // Inicialización
  // ---------------------------------------------------------------------------
  Future<void> initialize() async {
    debugPrint('🔧 Inicializando OfflineQueueService');
    try {
      await _loadQueuedProducts(); // carga lo que había en disco
      await _loadOrders();
      debugPrint('📦 Cargados ${_queuedProducts.length} productos en la cola');
      
      // Cancelar suscripciones anteriores para evitar duplicados
      _connectivitySubscription?.cancel();
      
      // Suscribirse a cambios de conectividad
      _connectivitySubscription = _connectivityService.connectivityStream.listen(_onConnectivityChange);
      debugPrint('🔌 Listener de conectividad configurado');
      
      // Configurar verificación periódica
      _setupPeriodicCheck();
      debugPrint('⏰ Verificación periódica configurada');
      
      // Verificar inmediatamente si hay conexión y procesar
      _processIfOnline();
      
      debugPrint('✅ OfflineQueueService inicializado correctamente');
    } catch (e, st) {
      debugPrint('🚨 Error al inicializar OfflineQueueService: $e\n$st');
      // Asegurar que incluso con error, la cola se inicialice vacía
      _queuedProducts = [];
      _notify();
    }
  }

  void _setupPeriodicCheck() {
    _processingTimer?.cancel();
    _processingTimer =
        Timer.periodic(const Duration(minutes: 15), (_) => _processIfOnline());
    debugPrint('⏱️ Temporizador de verificación configurado (cada 15 min)');
  }

  void _onConnectivityChange(bool hasInternet) {
    debugPrint('🔌 Cambio de conectividad detectado: $hasInternet');
    
    if (hasInternet) {
      // Agregar un pequeño retraso para asegurar que la conexión sea estable
      Future.delayed(const Duration(seconds: 2), () async {
        // Verificar nuevamente la conectividad para confirmar
        if (await _connectivityService.checkConnectivity()) {
          debugPrint('🔌 Conexión confirmada, procesando cola...');
          processQueue();
          processOrderQueue();
        }
      });
    }
  }

  Future<void> _processIfOnline() async {
    debugPrint('🔍 Verificando conectividad para procesar cola...');
    if (await _connectivityService.checkConnectivity()) {
      debugPrint('✅ Conexión disponible, procesando cola');
      processQueue();
      processOrderQueue();
    } else {
      debugPrint('❌ Sin conexión, no se procesará la cola ahora');
    }
  }

  // ---------------------------------------------------------------------------
  //  Carga / Guarda en SharedPreferences
  // ---------------------------------------------------------------------------
  Future<void> _loadQueuedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_storageKey) ?? [];

      debugPrint('📂 Cargando cola desde SharedPreferences (${raw.length} elementos)');
      _queuedProducts = raw
          .map((s) => QueuedProductModel.fromJson(jsonDecode(s)))
          .toList();

      _notify(); // primer disparo para quien ya está escuchando
      debugPrint('✅ Cola cargada exitosamente');
    } catch (e, st) {
      debugPrint('🚨 Error al cargar la cola: $e\n$st');
      _queuedProducts = [];
      _notify();
    }
  }

  Future<void> _saveQueuedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _queuedProducts.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_storageKey, raw);
      debugPrint('💾 Cola guardada en SharedPreferences (${raw.length} elementos)');
    } catch (e) {
      debugPrint('🚨 Error al guardar la cola: $e');
    }
  }

  // ---------------------------------------------------------------------------
  //  API pública
  // ---------------------------------------------------------------------------
  Future<String> addToQueue(ProductModel product) async {
    final id = const Uuid().v4();
    debugPrint('➕ Añadiendo producto a la cola: ${product.title} (ID: $id)');

    _queuedProducts.add(
      QueuedProductModel(
        queueId: id,
        product: product,
        status: 'queued',
        queuedTime: DateTime.now(),
      ),
    );

    await _saveQueuedProducts();
    _notify();
    _processIfOnline();
    debugPrint('✅ Producto añadido a la cola con ID: $id');

    return id;
  }

  Future<void> removeFromQueue(String id) async {
    debugPrint('🗑️ Eliminando producto de la cola: $id');
    _queuedProducts.removeWhere((p) => p.queueId == id);
    await _saveQueuedProducts();
    _notify();
    debugPrint('✅ Producto eliminado de la cola: $id');
  }

  Future<void> retryQueuedUpload(String id) async {
    debugPrint('🔄 Reintentando subida del producto: $id');
    final idx = _queuedProducts.indexWhere((p) => p.queueId == id);
    if (idx == -1) {
      debugPrint('⚠️ Producto no encontrado en la cola: $id');
      return;
    }

    _queuedProducts[idx] = _queuedProducts[idx].copyWith(
      status: 'queued',
      errorMessage: null,
    );

    await _saveQueuedProducts();
    _notify();
    debugPrint('✅ Producto marcado para reintento: $id');
    _processIfOnline();
  }

  /// Procesa toda la cola (si no se está procesando ya).
  Future<void> processQueue() async {
    if (_isProcessing) {
      debugPrint('⚠️ Ya hay un procesamiento en curso, abortando');
      return;
    }
    
    debugPrint('🔄 Iniciando procesamiento de cola');
    _isProcessing = true;

    try {
      // Verificar conectividad primero
      if (!await _connectivityService.checkConnectivity()) {
        debugPrint('📵 Sin conexión, abortando procesamiento');
        _isProcessing = false;
        return;
      }

      // Obtener productos para subir
      final toUpload = _queuedProducts.where((qp) =>
              qp.status == 'queued' ||
              (qp.status == 'failed' && qp.retryCount < _maxRetries))
          .toList();

      debugPrint('📋 Productos para procesar: ${toUpload.length}');
      
      if (toUpload.isEmpty) {
        debugPrint('✅ No hay productos para procesar');
        _isProcessing = false;
        return;
      }

      // Procesar cada producto
      for (final qp in toUpload) {
        debugPrint('⬆️ Procesando producto: ${qp.queueId} (${qp.product.title})');
        await _updateStatus(qp.queueId, 'uploading');

        try {
          // ------------------- 1. subir imágenes -------------------
          final uploaded = <String>[];
          final pendingPaths = qp.product.pendingImagePaths ?? [];
          
          debugPrint('🖼️ Subiendo ${pendingPaths.length} imágenes');
          
          for (final local in pendingPaths) {
            // Verificar si el archivo existe
            final file = File(local);
            if (!await file.exists()) {
              debugPrint('⚠️ Archivo no encontrado: $local');
              throw 'Archivo no encontrado: $local';
            }
            
            // Subir imagen con timeout
            String? url;
            try {
              url = await _firebaseDAO.uploadProductImage(local)
                  .timeout(const Duration(seconds: 30));
            } catch (e) {
              debugPrint('⚠️ Error subiendo imagen: $e');
              throw 'Error subiendo imagen: $e';
            }
            
            if (url != null) {
              uploaded.add(url);
              debugPrint('✅ Imagen subida: $url');
            } else {
              debugPrint('⚠️ URL nula al subir $local');
              throw 'Error subiendo $local: URL nula';
            }
          }

          // ------------------- 2. crear documento -------------------
          debugPrint('📄 Creando documento del producto');
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
            debugPrint('⚠️ Error creando producto: $e');
            throw 'Error creando producto: $e';
          }
          
          if (newId == null) {
            debugPrint('⚠️ ID nulo al crear producto');
            throw 'createProduct devolvió null';
          }

          debugPrint('✅ Producto creado con ID: $newId');
          await _updateStatus(qp.queueId, 'completed');
          
          // Limpieza diferida
          Timer(const Duration(hours: 24), () {
            removeCompletedItems();
          });
        } catch (e) {
          debugPrint('❌ Error procesando producto ${qp.queueId}: $e');
          await _updateStatus(
            qp.queueId,
            'failed',
            error: e.toString(),
          );
        }
      }
      
      debugPrint('✅ Procesamiento de cola completado');
    } catch (e, st) {
      debugPrint('🚨 Error general en processQueue: $e\n$st');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> removeCompletedItems() async {
    debugPrint('🧹 Limpiando productos completados antiguos');
    final initialCount = _queuedProducts.length;
    _queuedProducts.removeWhere((p) =>
        p.status == 'completed' &&
        DateTime.now().difference(p.queuedTime).inHours > 24);
    
    final removedCount = initialCount - _queuedProducts.length;
    if (removedCount > 0) {
      debugPrint('🗑️ Se eliminaron $removedCount productos completados antiguos');
      await _saveQueuedProducts();
      _notify();
    } else {
      debugPrint('ℹ️ No se encontraron productos completados antiguos para eliminar');
    }
  }

  // ---------------------------------------------------------------------------
  //  Auxiliares privados
  // ---------------------------------------------------------------------------
  Future<void> _updateStatus(String id, String status, {String? error}) async {
    final idx = _queuedProducts.indexWhere((p) => p.queueId == id);
    if (idx == -1) {
      debugPrint('⚠️ No se encontró el producto $id para actualizar estado');
      return;
    }

    debugPrint('🔄 Actualizando estado de $id a "$status"${error != null ? " (error: $error)" : ""}');
    
    var qp = _queuedProducts[idx].copyWith(status: status);
    if (status == 'failed') {
      qp = qp.copyWith(
        retryCount: qp.retryCount + 1,
        errorMessage: error,
      );
    }

    _queuedProducts[idx] = qp;
    await _saveQueuedProducts();
    _notify();
    debugPrint('✅ Estado actualizado para $id: $status');
  }

  void _notify() => _internalController.add(List.unmodifiable(_queuedProducts));

  // ---------------------------------------------------------------------------
  //  Limpieza
  // ---------------------------------------------------------------------------
  void dispose() {
    debugPrint('🧹 Limpiando recursos de OfflineQueueService');
    _processingTimer?.cancel();
    _connectivitySubscription?.cancel();
    _internalController.close();
    _orderController.close();
    debugPrint('✅ OfflineQueueService limpiado correctamente');
  }


  //Vainas para el orders
  //controller solo para ordenes
  final _orderController = StreamController<List<QueuedOrderModel>>.broadcast();

  Stream<List<QueuedOrderModel>> get orderQueueStream => Stream.multi((controller) {
    controller.add(List.unmodifiable(_queuedOrders));
    final sub = _orderController.stream.listen(controller.add);
    controller.onCancel = () => sub.cancel();
  });

  List<QueuedOrderModel> get queuedOrders => List.unmodifiable(_queuedOrders);

    // Order Operations
  Future<String> addOrderToQueue(String orderID, String hashConfirm) async {
    final id = const Uuid().v4();
    debugPrint('➕ Adding order to queue: $orderID');
    
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