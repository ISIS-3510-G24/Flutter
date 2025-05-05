// connectivity_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  // Singleton instance
  static final ConnectivityService _instance = ConnectivityService._internal();
  
  // Factory constructor that returns the singleton instance
  factory ConnectivityService() => _instance;
  
  // Private constructor
  ConnectivityService._internal() {
    _initialize();
  }
  
  // Dependencies
  final Connectivity _connectivity = Connectivity();
  
  // State
  bool _hasInternetAccess = true;
  bool _isConnected = true;
  bool _isCheckingConnectivity = false;
  
  // Controllers for broadcasting connectivity status
  final _connectivityController = StreamController<bool>.broadcast();
  final _checkingController = StreamController<bool>.broadcast(); // New controller for checking status
  
  // Public streams that screens can listen to
  Stream<bool> get connectivityStream => _connectivityController.stream;
  Stream<bool> get checkingStream => _checkingController.stream; // New getter for checking status
  
  // Public getter for current status
  bool get hasInternetAccess => _hasInternetAccess;
  bool get isChecking => _isCheckingConnectivity;
  
  // Initialize the service
  void _initialize() {
    // Start with optimistic assumption
    _hasInternetAccess = true;
    
    // Initial check
    _performConnectivityCheckWithIsolate();
    
    // Set up continuous monitoring
    _setupConnectivityListener();
  }
  
  // Set up listener for connectivity changes
  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Check actual internet when connectivity status changes
      if (!_isCheckingConnectivity) {
        _performConnectivityCheckWithIsolate();
      }
    });
  }
  
  // Isolate function for connectivity check
  static void _connectivityCheckIsolate(SendPort sendPort) async {
    bool hasAccess = false;
    
    try {
      // Try to connect to a reliable service (Google DNS)
      final socket = await Socket.connect('8.8.8.8', 53)
          .timeout(Duration(seconds: 3));
      socket.destroy();
      hasAccess = true;
    } catch (e) {
      hasAccess = false;
    }
    
    // Send result to main thread
    sendPort.send(hasAccess);
  }
  
  // Check connectivity using an isolate
  Future<void> _performConnectivityCheckWithIsolate() async {
    if (_isCheckingConnectivity) return;
    
    _isCheckingConnectivity = true;
    _checkingController.add(true); // Notify listeners that we're checking
    
    // Add a timeout to prevent getting stuck in checking state
    Timer timeoutTimer = Timer(Duration(seconds: 5), () {
      if (_isCheckingConnectivity) {
        _isCheckingConnectivity = false;
        _checkingController.add(false);
        _updateInternetStatus(false); // Assume no connection if timeout
      }
    });
    
    try {
      // First check interface level
      final results = await _connectivity.checkConnectivity();
      bool hasInterface = results.isNotEmpty && results.first != ConnectivityResult.none;
      
      // If no interface connected, definitely no internet
      if (!hasInterface) {
        _isConnected = false;
        _updateInternetStatus(false);
        _isCheckingConnectivity = false;
        _checkingController.add(false); // Notify listeners we're done checking
        timeoutTimer.cancel();
        return;
      }
      
      // Update interface status
      _isConnected = true;
      
      // Create a receive port for communication with the isolate
      final receivePort = ReceivePort();
      
      try {
        // Launch the isolate to check real connectivity
        Isolate isolate = await Isolate.spawn(
          _connectivityCheckIsolate, 
          receivePort.sendPort
        );
        
        // Wait for response with timeout
        bool hasInternet = await receivePort.first.timeout(
          Duration(seconds: 3),
          onTimeout: () => false,
        );
        
        // Clean up the isolate
        isolate.kill(priority: Isolate.immediate);
        receivePort.close();
        
        // Update the status
        _updateInternetStatus(hasInternet);
      } catch (e) {
        print("Error in isolate: $e");
        _updateInternetStatus(false);
      }
    } catch (e) {
      print("Error checking connectivity: $e");
      _updateInternetStatus(false); // Assume no connection on error
    } finally {
      // Always exit checking state and cancel timeout
      _isCheckingConnectivity = false;
      _checkingController.add(false); // Notify listeners we're done checking
      timeoutTimer.cancel();
    }
  }
  
  // Update internet status and notify listeners
  void _updateInternetStatus(bool status) {
    if (_hasInternetAccess != status) {
      _hasInternetAccess = status;
      _connectivityController.add(status);
    }
  }
  
  // Public method to force a connectivity check
  Future<bool> checkConnectivity() async {
    await _performConnectivityCheckWithIsolate();
    return _hasInternetAccess;
  }
  
  // Dispose resources
  void dispose() {
    _connectivityController.close();
    _checkingController.close(); // Close the new controller
  }
}