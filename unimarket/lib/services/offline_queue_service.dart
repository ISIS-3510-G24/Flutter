import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/services/connectivity_service.dart';

// Define a QueuedProductModel to store product queue information
class QueuedProductModel {
  final String queueId;
  final ProductModel product;
  final String status; // 'queued', 'uploading', 'completed', 'failed'
  final DateTime queuedTime;
  final String? errorMessage;
  final int retryCount;

  QueuedProductModel({
    required this.queueId,
    required this.product,
    required this.status,
    required this.queuedTime,
    this.errorMessage,
    this.retryCount = 0,
  });

  // Convert to map for storage
  Map<String, dynamic> toJson() {
    return {
      'queueId': queueId,
      'product': product.toJson(),
      'status': status,
      'queuedTime': queuedTime.toIso8601String(),
      'errorMessage': errorMessage,
      'retryCount': retryCount,
    };
  }

  // Create from map for retrieval
  factory QueuedProductModel.fromJson(Map<String, dynamic> json) {
    return QueuedProductModel(
      queueId: json['queueId'],
      product: ProductModel.fromJson(json['product']),
      status: json['status'],
      queuedTime: DateTime.parse(json['queuedTime']),
      errorMessage: json['errorMessage'],
      retryCount: json['retryCount'] ?? 0,
    );
  }

  // Create a copy with updated fields
  QueuedProductModel copyWith({
    String? queueId,
    ProductModel? product,
    String? status,
    DateTime? queuedTime,
    String? errorMessage,
    int? retryCount,
  }) {
    return QueuedProductModel(
      queueId: queueId ?? this.queueId,
      product: product ?? this.product,
      status: status ?? this.status,
      queuedTime: queuedTime ?? this.queuedTime,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

class OfflineQueueService {
  // Singleton implementation
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  // Dependencies
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Stream controller for queue updates
  final _queueStreamController = StreamController<List<QueuedProductModel>>.broadcast();
  
  // Internal queue state
  List<QueuedProductModel> _queuedProducts = [];
  bool _isProcessing = false;
  Timer? _processingTimer;
  
  // Constants
  static const String _queueStorageKey = 'offline_product_queue';
  static const int _maxRetryCount = 3;
  static const Duration _retryDelay = Duration(minutes: 5);
  
  // Getters
  Stream<List<QueuedProductModel>> get queueStream => _queueStreamController.stream;
  List<QueuedProductModel> get queuedProducts => List.unmodifiable(_queuedProducts);
  
  // Initialize service
  Future<void> initialize() async {
    // Load existing queued products
    await _loadQueuedProducts();
    
    // Set up listener for connectivity changes
    _connectivityService.connectivityStream.listen(_handleConnectivityChange);
    
    // Start periodic check for retrying uploads
    _setupPeriodicCheck();
  }

  // Setup periodic check for retrying uploads
  void _setupPeriodicCheck() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _processQueueIfOnline();
    });
  }

  // Handle connectivity change
  void _handleConnectivityChange(bool hasInternet) {
    if (hasInternet) {
      _processQueueIfOnline();
    }
  }

  // Process queue if device is online
  Future<void> _processQueueIfOnline() async {
    final hasInternet = await _connectivityService.checkConnectivity();
    if (hasInternet && !_isProcessing) {
      processQueue();
    }
  }

  // Load queued products from storage
  Future<void> _loadQueuedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queuedProductsJson = prefs.getStringList(_queueStorageKey) ?? [];
      
      _queuedProducts = queuedProductsJson.map((json) {
        try {
          return QueuedProductModel.fromJson(jsonDecode(json));
        } catch (e) {
          debugPrint('Error parsing queued product: $e');
          return null;
        }
      }).whereType<QueuedProductModel>().toList();
      
      // Notify listeners
      _notifyQueueUpdated();
      
    } catch (e) {
      debugPrint('Error loading queued products: $e');
      _queuedProducts = [];
    }
  }

  // Save queued products to storage
  Future<void> _saveQueuedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queuedProductsJson = _queuedProducts.map((product) => 
        jsonEncode(product.toJson())).toList();
      
      await prefs.setStringList(_queueStorageKey, queuedProductsJson);
    } catch (e) {
      debugPrint('Error saving queued products: $e');
    }
  }

  // Add a product to the queue
  Future<String> addToQueue(ProductModel product) async {
    // Generate a unique ID for this queued item
    final queueId = const Uuid().v4();
    
    // Create the queued product
    final queuedProduct = QueuedProductModel(
      queueId: queueId,
      product: product,
      status: 'queued',
      queuedTime: DateTime.now(),
    );
    
    // Add to queue
    _queuedProducts.add(queuedProduct);
    
    // Save and notify
    await _saveQueuedProducts();
    _notifyQueueUpdated();
    
    // If online, start processing
    _processQueueIfOnline();
    
    return queueId;
  }

  // Update status of a queued product
  Future<void> updateQueuedProductStatus(String queueId, String status, {String? errorMessage}) async {
    final index = _queuedProducts.indexWhere((product) => product.queueId == queueId);
    
    if (index != -1) {
      // Update the status
      _queuedProducts[index] = _queuedProducts[index].copyWith(
        status: status,
        errorMessage: errorMessage,
      );
      
      // If failed, increment retry count
      if (status == 'failed') {
        _queuedProducts[index] = _queuedProducts[index].copyWith(
          retryCount: _queuedProducts[index].retryCount + 1,
        );
      }
      
      // Save and notify
      await _saveQueuedProducts();
      _notifyQueueUpdated();
    }
  }

  // Remove a product from the queue
  Future<void> removeFromQueue(String queueId) async {
    _queuedProducts.removeWhere((product) => product.queueId == queueId);
    
    // Save and notify
    await _saveQueuedProducts();
    _notifyQueueUpdated();
  }

  // Process the queue (upload pending products)
  Future<void> processQueue() async {
    if (_isProcessing) return;
    
    try {
      _isProcessing = true;
      
      // Check for internet connection
      final hasInternet = await _connectivityService.checkConnectivity();
      if (!hasInternet) {
        debugPrint('No internet connection, skipping queue processing');
        return;
      }
      
      // Get products that need to be uploaded
      final productsToUpload = _queuedProducts.where((product) => 
        product.status == 'queued' || 
        (product.status == 'failed' && product.retryCount < _maxRetryCount)).toList();
      
      if (productsToUpload.isEmpty) {
        debugPrint('No products to upload in queue');
        return;
      }
      
      // Process each product
      for (final product in productsToUpload) {
        try {
          // Mark as uploading
          await updateQueuedProductStatus(product.queueId, 'uploading');
          
          // [THIS IS WHERE YOU WOULD INSERT ACTUAL UPLOAD LOGIC]
          // For example:
          // final success = await _firebaseDAO.uploadQueuedProduct(product.product);
          
          // For testing/placeholder, we'll simulate a success or failure
          final success = true; // Replace with real implementation
          
          // Update status based on result
          if (success) {
            await updateQueuedProductStatus(product.queueId, 'completed');
            
            // Schedule to remove completed items after some time
            Timer(const Duration(hours: 24), () {
              removeCompletedItems();
            });
          } else {
            await updateQueuedProductStatus(
              product.queueId, 
              'failed', 
              errorMessage: 'Upload failed'
            );
          }
        } catch (e) {
          debugPrint('Error uploading queued product: $e');
          await updateQueuedProductStatus(
            product.queueId, 
            'failed', 
            errorMessage: 'Error: $e'
          );
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  // Manually retry uploading a specific product
  Future<void> retryQueuedUpload(String queueId) async {
    final index = _queuedProducts.indexWhere((product) => product.queueId == queueId);
    
    if (index != -1) {
      // Reset status to queued
      _queuedProducts[index] = _queuedProducts[index].copyWith(
        status: 'queued',
        errorMessage: null,
      );
      
      // Save and notify
      await _saveQueuedProducts();
      _notifyQueueUpdated();
      
      // Process queue if online
      _processQueueIfOnline();
    }
  }

  // Remove completed items that are more than 24 hours old
  Future<void> removeCompletedItems() async {
    final now = DateTime.now();
    _queuedProducts.removeWhere((product) => 
      product.status == 'completed' && 
      now.difference(product.queuedTime).inHours > 24);
    
    // Save and notify
    await _saveQueuedProducts();
    _notifyQueueUpdated();
  }

  // Notify listeners of queue updates
  void _notifyQueueUpdated() {
    _queueStreamController.add(_queuedProducts);
  }

  // Clean up resources
  void dispose() {
    _processingTimer?.cancel();
    _queueStreamController.close();
  }
}