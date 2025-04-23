import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:unimarket/data/firebase_dao.dart';
/// Un servicio singleton para manejar la conectividad en toda la aplicación y evitar problemas con MissingPluginException
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  static final _pendingOrderUpdates = <Map<String, dynamic>>[];
  static bool _isProcessingQueue = false;
  static FirebaseDAO? _firebaseDao;
  
  ConnectivityService._internal() {
    // Inicializar listeners en una manera segura
    _initConnectivity();
  }

  final Connectivity _connectivity = Connectivity();
  StreamController<bool> connectionStatusController = StreamController<bool>.broadcast();
  bool _hasConnection = true;

  // Getter para el estado actual
  bool get hasConnection => _hasConnection;

  // Inicializa la conectividad de forma segura
  void _initConnectivity() {
    try {
      _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
      
      // Verificar estado inicial
      _checkInitialConnection();
    } catch (e) {
      print("Error inicializando el servicio de conectividad: $e");
      // Asumir conectado por defecto
      _hasConnection = true;
      connectionStatusController.add(_hasConnection);
    }
  }

  Future<void> _checkInitialConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      print("Error al verificar la conectividad inicial: $e");
      // Asumir conectado por defecto
      _hasConnection = true;
      connectionStatusController.add(_hasConnection);
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    ConnectivityResult result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _hasConnection = result != ConnectivityResult.none;
    connectionStatusController.add(_hasConnection);
  }

  // Método para verificar la conectividad bajo demanda
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      ConnectivityResult result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _hasConnection = result != ConnectivityResult.none;
      connectionStatusController.add(_hasConnection);
    } catch (e) {
      print("Error verificando conectividad: $e");
      // No cambiar el estado en caso de error
    }
    return _hasConnection;
  }

  // No olvidar cerrar el stream controller cuando se cierre la aplicación
  void dispose() {
    connectionStatusController.close();
  }
  static void initializeOrderSync(FirebaseDAO firebaseDao) {
    _firebaseDao = firebaseDao;
    _instance._connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        _processPendingOrderUpdates();
      }
    });
  }

  // Add this method to queue updates
  static Future<void> queueOrderUpdate({
    required String orderId,
    required String hashConfirm,
  }) async {
    _pendingOrderUpdates.add({
      'orderId': orderId,
      'hashConfirm': hashConfirm,
      'timestamp': DateTime.now(),
    });
    
    if (_instance._hasConnection) {
      await _processPendingOrderUpdates();
    }
  }

  // Debería funcionar ojala
  static Future<void> _processPendingOrderUpdates() async {
  if (_isProcessingQueue || _pendingOrderUpdates.isEmpty || _firebaseDao == null) return;
  
  _isProcessingQueue = true;
  try {
    for (final update in List.of(_pendingOrderUpdates)) {
      try {
        await _firebaseDao!.updateOrderStatusDelivered(
          update['orderId'] as String,
          update['hashConfirm'] as String,
        );
        _pendingOrderUpdates.remove(update);
      } catch (e) {
        print('Failed to process queued order update: $e');
        break;
      }
    }
  } finally {
    _isProcessingQueue = false;
  }
}

    void onRestoredConnection(Function callback) {
    _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected && !_hasConnection) {
        callback();
      }
      _updateConnectionStatus(results);
    });
  }
}