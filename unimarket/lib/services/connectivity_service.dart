import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Un servicio singleton para manejar la conectividad en toda la aplicación y evitar problemas con MissingPluginException
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  
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
}