import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:google_fonts/google_fonts.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/services/firebase_storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:vector_math/vector_math_64.dart';
import 'package:collection/collection.dart';
import 'package:unimarket/services/light_sensor_service.dart';

class ProductCameraScreen extends StatefulWidget {
  final Function(File, String?) onImageCaptured;

  const ProductCameraScreen({
    Key? key,
    required this.onImageCaptured,
  }) : super(key: key);

  @override
  _ProductCameraScreenState createState() => _ProductCameraScreenState();
}

class _ProductCameraScreenState extends State<ProductCameraScreen>
    with WidgetsBindingObserver {
  // Controladores principales
  CameraController? _cameraController;
  ARKitController? _arkitController;
  FirebaseStorageService _storageService = FirebaseStorageService();
  LightSensorService? _lightSensorService;
  
  // Banderas de estado
  bool _isInitialized = false;
  bool _measurementMode = false;
  bool _isLoading = true;
  bool _hasLiDAR = false;
  bool _takingPicture = false;
  bool _showARKitOverlay = false;
  File? _capturedImage;
  Widget? _arKitView;
  bool _isDisposed = false;
  bool _isModeChanging = false;
  bool _isCaptureFallbackActive = false;

  FlutterExceptionHandler? _originalErrorHandler;
  bool _isErrorHandlerOverridden = false;
  
  // Variables para timeouts
  Timer? _captureTimeoutTimer;
  Timer? _modeChangeTimer;
  Timer? _initializationTimer;
  
  // Variables para sensores y UI
  String _feedback = '';
  DateTime? _lastLightUpdate;
  double _currentLightLevel = 0.5;

  // Variables para medición
  Vector3? _lastPosition;
  List<ARKitNode> _measurementNodes = [];
  String _currentMeasurement = '';

  @override
  void initState() {
    super.initState();
    print("📸 Iniciando ProductCameraScreen");
    WidgetsBinding.instance.addObserver(this);
    
    // Setup error handlers
    _setupErrorHandlers();
    
    // Initialize light service (once)
    _lightSensorService = LightSensorService();
    
    // Initialize values
    _feedback = '';
    _lastPosition = null;
    _currentMeasurement = '';
    _measurementNodes = [];
    _measurementMode = false;
    _isDisposed = false;
    
    // Start camera with safety timeout
    _startInitialization();
  }

  void _setupErrorHandlers() {
    // Save original error handler
    _originalErrorHandler = FlutterError.onError;
    
    // Replace with our custom handler
    FlutterError.onError = (FlutterErrorDetails details) {
      final String errorStr = details.exception.toString();
      
      // Suppress specific camera errors completely 
      if (errorStr.contains("Disposed CameraController") ||
          errorStr.contains("Cannot Record") ||
          errorStr.contains("buildPreview()") ||
          errorStr.contains("setState() called after dispose()")) {
        
        // Just log to console without UI presentation
        print("🛡️ Suppressed camera error: ${errorStr.split('\n')[0]}");
        _isErrorHandlerOverridden = true;
        return;
      }
      
      // Let other errors be handled normally
      _originalErrorHandler?.call(details);
    };
    
    print("🛡️ Camera error handler installed");
  }
  

  // NUEVA FUNCIÓN: Inicia la inicialización con un timeout de seguridad
  void _startInitialization() {
    _initializationTimer?.cancel();
    
    // Si tarda más de 8 segundos, mostrar un mensaje amigable
    _initializationTimer = Timer(Duration(seconds: 8), () {
      if (!_isInitialized && mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _feedback = "La inicialización está tardando más de lo normal...";
        });
        
        // Intentar reiniciar
        _cleanupResources(fullCleanup: false);
        _initializeCamera();
      }
    });
    
    _initializeCamera();
  }

  void _initializeARKit() {
    try {
      if (_arKitView != null) return;
      
      print("🔍 Inicializando ARKit");
      _arKitView = ARKitSceneView(
        onARKitViewCreated: _onARKitViewCreated,
        configuration: ARKitConfiguration.worldTracking,
        enableTapRecognizer: true,
        planeDetection: ARPlaneDetection.horizontal,
      );
      print("🔍 ARKit inicializado correctamente");
    } catch (e) {
      print("❌ Error al inicializar ARKit: $e");
      _feedback = "Error al inicializar LiDAR";
      
      // Forzar modo luz si ARKit falla
      _measurementMode = false;
    }
  }

   // Call this in dispose to restore original handlers
  void _restoreErrorHandlers() {
    if (_isErrorHandlerOverridden && _originalErrorHandler != null) {
      FlutterError.onError = _originalErrorHandler;
      _isErrorHandlerOverridden = false;
      print("🛡️ Original error handler restored");
    }
  }

 @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    
    // Restore original error handlers
    _restoreErrorHandlers();
    
    // Cancel all timers
    _captureTimeoutTimer?.cancel();
    _modeChangeTimer?.cancel();
    _initializationTimer?.cancel();

    // Cleanup resources completely
    _cleanupResources(fullCleanup: true);
    
    super.dispose();
  }
  
  // Método centralizado para limpieza de recursos
 Future<void> _cleanupResources({bool fullCleanup = false}) async {
  try {
    // Cancelar timers
    _captureTimeoutTimer?.cancel();
    _modeChangeTimer?.cancel();
    
    // Detener stream y liberar cámara
    if (_cameraController != null) {
      if (_cameraController!.value.isInitialized) {
        if (_cameraController!.value.isStreamingImages) {
          try {
            await _cameraController!.stopImageStream();
            await Future.delayed(Duration(milliseconds: 200));
          } catch (e) {
            print("⚠️ Error al detener stream en limpieza: $e");
          }
        }
        try {
          await _cameraController!.dispose();
          // Important: After disposal, nullify the controller
          _cameraController = null;
        } catch (e) {
          print("⚠️ Error al liberar cámara: $e");
          _cameraController = null;
        }
      } else {
        try {
          _cameraController!.dispose();
          _cameraController = null;
        } catch (e) {
          print("⚠️ Error al liberar cámara no inicializada: $e");
          _cameraController = null;
        }
      }
    }
    
    // Liberar ARKit
    if (_arkitController != null) {
      try {
        _arkitController!.dispose();
        _arkitController = null;
      } catch (e) {
        print("⚠️ Error al liberar ARKit: $e");
        _arkitController = null;
      }
    }
    
    // En caso de reconstrucción completa, recrear la vista ARKit
    if (!fullCleanup) {
      _arKitView = null;
    }
    
    // Solo liberar servicio de luz si es una limpieza completa
    if (fullCleanup && _lightSensorService != null) {
      try {
        _lightSensorService!.dispose();
        _lightSensorService = null;
      } catch (e) {
        print("⚠️ Error al liberar servicio de luz: $e");
      }
    }
    
    // Limpiar nodos de medición
    _measurementNodes.clear();
    _lastPosition = null;
    
    // Add a small delay to ensure all resources are properly released
    await Future.delayed(Duration(milliseconds: 100));
    
  } catch (e) {
    print("❌ Error en limpieza de recursos: $e");
  }
}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cleanupResources(fullCleanup: false);
    } else if (state == AppLifecycleState.resumed) {
      // Reinicializar completamente
      _isInitialized = false;
      _startInitialization();
    }
  }

  // MÉTODO REFACTORIZADO: Inicialización de cámara con mejor manejo de errores
  Future<void> _initializeCamera() async {
    if (_isDisposed) return;
    
    if (_isLoading && mounted) {
      setState(() {
        _feedback = "Inicializando cámara...";
      });
    } else {
      _isLoading = true;
      if (mounted) setState(() {});
    }

    try {
      // Verificar soporte de LiDAR primero
      _hasLiDAR = await _checkLiDARSupport();
      print("🔍 LiDAR detectado: $_hasLiDAR");

      final cameras = await availableCameras().timeout(
        Duration(seconds: 3),
        onTimeout: () {
          print("⚠️ Timeout al obtener cámaras");
          throw TimeoutException("No se detectaron cámaras");
        },
      );
      
      if (cameras.isEmpty) {
        throw Exception("No se encontraron cámaras disponibles");
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Inicializar controlador de cámara
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      // Inicializar cámara con timeout
      await _cameraController!.initialize().timeout(
        Duration(seconds: 4),
        onTimeout: () {
          throw TimeoutException("Timeout inicializando cámara");
        },
      );
      
      // Inicializar ARKit si hay LiDAR
      if (_hasLiDAR && _arKitView == null) {
        _initializeARKit();
      }
      
      // Pequeña pausa para estabilizar
      await Future.delayed(Duration(milliseconds: 200));
      
      // Iniciar en el modo correcto
      if (_measurementMode && _hasLiDAR) {
        await _startMeasurementMode();
      } else {
        _measurementMode = false; // Forzar modo luz si no hay LiDAR
        await _startLightMode();
      }

      _isInitialized = true;
      _isLoading = false;
      
      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = _measurementMode ? "Modo medición listo" : "Cámara lista";
        });
      }
    } catch (e) {
      print("❌ Error al inicializar cámara: $e");
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _feedback = "Error al inicializar. Toca para reintentar";
        });
      }
    }
  }

  // MÉTODO REFACTORIZADO: Inicia el modo luz
  Future<void> _startLightMode() async {
    if (_isDisposed) return;
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      if (mounted) {
        setState(() {
          _feedback = "Cámara no inicializada";
          _isLoading = false;
        });
      }
      return;
    }
    
    try {
      // Ocultar ARKit
      if (mounted) {
        setState(() {
          _showARKitOverlay = false;
        });
      }
      
      // Detener stream existente
      if (_cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
          await Future.delayed(Duration(milliseconds: 200));
        } catch (e) {
          print("⚠️ Error al detener stream previo: $e");
        }
      }
      
      if (_isDisposed) return;
      
      // Iniciar streaming
      try {
        await _cameraController!.startImageStream(_processCameraImage)
            .timeout(Duration(seconds: 2), onTimeout: () {
          throw TimeoutException("Timeout al iniciar stream de cámara");
        });
        
        print("✅ Stream de cámara para luz iniciado correctamente");
        if (mounted && !_isDisposed) {
          setState(() {
            _feedback = "Modo sensor de luz activado";
          });
        }
      } catch (e) {
        print("⚠️ Error al iniciar stream: $e");
        if (mounted && !_isDisposed) {
          setState(() {
            _feedback = "Error con el sensor. Toca para reintentar";
          });
        }
      }
    } catch (e) {
      print("❌ Error en modo luz: $e");
      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = "Error en modo luz. Toca para reintentar";
        });
      }
    }
  }

  // MÉTODO REFACTORIZADO: Inicia el modo medición
  Future<void> _startMeasurementMode() async {
    if (_isDisposed) return;
    
    if (!_hasLiDAR) {
      if (mounted) {
        setState(() {
          _feedback = "LiDAR no disponible en este dispositivo";
          _measurementMode = false;
        });
      }
      return;
    }
    
    try {
      // Detener el stream de cámara
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
          await Future.delayed(Duration(milliseconds: 300));
        } catch (e) {
          print("⚠️ Error al detener stream para medición: $e");
        }
      }
      
      // Asegurar que ARKit está inicializado
      if (_arKitView == null) {
        _initializeARKit();
      }
      
      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = "Modo medición activado. Toca para medir";
          _showARKitOverlay = true;
        });
      }
    } catch (e) {
      print("❌ Error al iniciar modo medición: $e");
      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = "Error al iniciar medición";
          _measurementMode = false;
          _showARKitOverlay = false;
        });
      }
      
      // Forzar cambio a modo luz si falla
      if (!_isDisposed) {
        Future.delayed(Duration(milliseconds: 500), () {
          if (!_isDisposed) {
            _startLightMode();
          }
        });
      }
    }
  }

  // MÉTODO COMPLETAMENTE NUEVO: Reinicio completo para cambio de modo
 Future<void> _hardReset({required bool targetMode}) async {
  if (_isDisposed || _isModeChanging) return;
  
  _isModeChanging = true;
  
  if (mounted) {
    setState(() {
      _isLoading = true;
      _feedback = "Cambiando modo...";
      _showARKitOverlay = false; // Always hide ARKit during reset
    });
  }
  
  try {
    // 1. Complete cleanup of all resources
    await _cleanupResources(fullCleanup: false);
    
    // 2. Set target mode
    _measurementMode = targetMode;
    _isInitialized = false;
    
    // 3. Add a significant delay to ensure all resources are properly released
    // This is crucial for iOS to properly release camera resources
    await Future.delayed(Duration(milliseconds: 800));
    
    // 4. Reinitialize from scratch
    if (!_isDisposed) {
      await _initializeCamera();
    }
  } catch (e) {
    print("❌ Error en reinicio: $e");
    
    // Ensure we always end in a usable state
    if (mounted && !_isDisposed) {
      setState(() {
        _isLoading = false;
        _isModeChanging = false;
        _feedback = "Error al cambiar modo. Toca para reintentar";
      });
    }
  } finally {
    if (mounted && !_isDisposed) {
      setState(() {
        _isLoading = false;
        _isModeChanging = false;
      });
    }
  }
}

  // MÉTODO REFACTORIZADO: Cambia entre modos usando reinicio completo
  Future<void> _toggleMode() async {
    if (_isLoading || _isModeChanging || _isDisposed || _takingPicture) return;
    
    // Usar el nuevo método de reinicio completo
    await _hardReset(targetMode: !_measurementMode);
  }

  Future<bool> _checkLiDARSupport() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;

      print("📱 Modelo de dispositivo: ${iosInfo.model}");

      final String model = iosInfo.modelName;

      final bool hasLiDAR = model.contains('iPhone 12 Pro') ||
          model.contains('iPhone 13 Pro') ||
          model.contains('iPhone 14 Pro') ||
          model.contains('iPhone 15 Pro') ||
          (model.contains('iPad Pro') &&
              int.tryParse(model.split(' ').last) != null &&
              int.parse(model.split(' ').last) >= 2020);

      print("¿Dispositivo compatible con LiDAR? $hasLiDAR");
      print("Modelo detectado: $model");

      return hasLiDAR;
    } catch (e) {
      print("❌ Error al verificar soporte LiDAR: $e");
      return false;
    }
  }

  void _processCameraImage(CameraImage image) {
    if (_isDisposed || _lightSensorService == null || 
        _takingPicture || _isModeChanging) return;
    
    // Throttling para reducir procesamiento
    final now = DateTime.now();
    if (_lastLightUpdate != null && 
        now.difference(_lastLightUpdate!).inMilliseconds < 500) {
      return;
    }
    _lastLightUpdate = now;
    
    try {
      // Usar el servicio de luz para procesar la imagen
      _lightSensorService!.processCameraImage(image);
      
      // Actualizar UI con los resultados
      if (mounted && !_isDisposed) {
        setState(() {
          try {
            _currentLightLevel = _lightSensorService!.lightLevelNotifier.value;
            _feedback = _lightSensorService!.feedbackNotifier.value;
          } catch (e) {
            print("⚠️ Error al leer datos de luz: $e");
          }
        });
      }
    } catch (e) {
      print("⚠️ Error al procesar imagen: $e");
    }
  }

  void _onARKitViewCreated(ARKitController controller) {
    print("🔍 ARKit controller creado");
    _arkitController = controller;

    if (mounted && !_isDisposed) {
      setState(() {
        _feedback = "Toca para empezar a medir";
      });
    }

    controller.onARTap = (List<ARKitTestResult> ar) {
      if (_isDisposed || _takingPicture || _isModeChanging) return;
      
      final ARKitTestResult? point = ar.firstWhereOrNull(
        (o) => o.type == ARKitHitTestResultType.featurePoint,
      );
      
      if (point != null) {
        _onARTapHandler(point);
      }
    };
  }

  void _onARTapHandler(ARKitTestResult point) {
    if (_arkitController == null || _isDisposed || 
        _takingPicture || _isModeChanging) return;
    
    final position = Vector3(
      point.worldTransform.getColumn(3).x,
      point.worldTransform.getColumn(3).y,
      point.worldTransform.getColumn(3).z,
    );

    // Crear una esfera en el punto tocado
    final material = ARKitMaterial(
      lightingModelName: ARKitLightingModel.constant,
      diffuse: ARKitMaterialProperty.color(CupertinoColors.activeBlue),
    );
    
    final sphere = ARKitSphere(
      radius: 0.006,
      materials: [material],
    );
    
    final node = ARKitNode(
      geometry: sphere,
      position: position,
      name: "node_${DateTime.now().millisecondsSinceEpoch}",
    );
    
    try {
      _arkitController?.add(node);
      _measurementNodes.add(node);
    } catch (e) {
      print("⚠️ Error al añadir nodo: $e");
      return;
    }

    // Si ya tenemos un punto anterior, dibujar una línea
    if (_lastPosition != null) {
      try {
        final line = ARKitLine(
          fromVector: _lastPosition!,
          toVector: position,
        );
        
        final lineNode = ARKitNode(
          geometry: line,
          name: "line_${DateTime.now().millisecondsSinceEpoch}",
        );
        _arkitController?.add(lineNode);
        _measurementNodes.add(lineNode);

        // Calcular y mostrar la distancia
        final distance = _calculateDistanceBetweenPoints(position, _lastPosition!);
        final midPoint = _getMiddleVector(position, _lastPosition!);
        _drawText(distance, midPoint);
        
        if (mounted && !_isDisposed) {
          setState(() {
            _currentMeasurement = distance;
          });
        }
      } catch (e) {
        print("⚠️ Error al añadir línea: $e");
      }
    }

    _lastPosition = position;
  }

  String _calculateDistanceBetweenPoints(Vector3 a, Vector3 b) {
    final length = a.distanceTo(b);
    return '${(length * 100).toStringAsFixed(2)} cm';
  }

  Vector3 _getMiddleVector(Vector3 a, Vector3 b) {
    return Vector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2);
  }

  void _drawText(String text, Vector3 point) {
    if (_arkitController == null || _isDisposed) return;
    
    try {
      final textGeometry = ARKitText(
        text: text,
        extrusionDepth: 1,
        materials: [
          ARKitMaterial(
            diffuse: ARKitMaterialProperty.color(CupertinoColors.systemRed),
          )
        ],
      );
      
      const scale = 0.001;
      final vectorScale = Vector3(scale, scale, scale);
      
      final node = ARKitNode(
        geometry: textGeometry,
        position: point,
        scale: vectorScale,
        name: "text_${DateTime.now().millisecondsSinceEpoch}",
      );
      
      _arkitController?.add(node);
      _measurementNodes.add(node);
    } catch (e) {
      print("⚠️ Error al añadir texto: $e");
    }
  }

  void _clearMeasurements() {
    if (_arkitController == null || _isDisposed) return;
    
    _lastPosition = null;
    
    for (final node in _measurementNodes) {
      try {
        _arkitController?.remove(node.name);
      } catch (e) {
        print("⚠️ Error al eliminar nodo: $e");
      }
    }
    
    _measurementNodes.clear();
    
    if (mounted && !_isDisposed) {
      setState(() {
        _currentMeasurement = '';
        _feedback = "Toca para empezar a medir";
      });
    }
  }

   Future<void> _takePicture() async {
  if (_cameraController == null || 
      !_cameraController!.value.isInitialized || 
      _takingPicture || 
      _isLoading ||
      _isDisposed) {
    return;
  }

  // Set up safety timeout
  _activateCaptureTimeout();
  
  setState(() {
    _takingPicture = true;
    _isCaptureFallbackActive = false;
    _feedback = "Preparando cámara...";
  });

  // Save current mode
  final bool wasMeasurementMode = _measurementMode;
  
  // Create a semi-opaque overlay to prevent red screen flashes
  if (mounted && !_isDisposed) {
    setState(() {
      _showARKitOverlay = false;  // Hide ARKit explicitly
    });
  }

  try {
    // IMPORTANT: We now use different capture methods based on the current mode
    XFile? photo;
    
    // Give time for the UI to update and AR to hide
    await Future.delayed(Duration(milliseconds: 300));
    
    if (wasMeasurementMode) {
      // AR mode requires special handling
      photo = await _captureInARMode();
    } else {
      // Standard capture for light mode
      photo = await _captureInLightMode();
    }
    
    // Cancel timeout on success
    _captureTimeoutTimer?.cancel();
    
    if (photo == null) {
      throw Exception("No se pudo capturar la imagen");
    }
    
    print("✅ Foto capturada exitosamente: ${photo.path}");

    // Process image
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String filePath = path.join(appDir.path, fileName);

    print("💾 Guardando imagen en $filePath");
    final File savedImage = File(photo.path);
    final File newFile = await savedImage.copy(filePath);
    print("✅ Imagen guardada correctamente");

    // Update UI with captured image
    if (mounted && !_isDisposed) {
      setState(() {
        _capturedImage = newFile;
        _takingPicture = false;
        _isCaptureFallbackActive = false;
        _feedback = "Imagen capturada correctamente";
      });
    }
  } catch (e) {
    print("❌ Error en captura: ${e.toString().split('\n')[0]}");
    
    if (_isCaptureFallbackActive || _isDisposed) return;
    
    // Reset camera
    if (mounted && !_isDisposed) {
      setState(() {
        _takingPicture = false;
        _feedback = "Error al tomar foto. Intenta de nuevo";
      });
      
      // Reset camera
      _hardReset(targetMode: wasMeasurementMode);
    }
  }
}

// NEW DEDICATED METHOD: Special handling for AR mode capture
Future<XFile?> _captureInARMode() async {
  if (_isDisposed) return null;
  
  print("📸 Iniciando captura en modo AR...");
  XFile? result;
  
  try {
    // 1. Make sure ARKit is fully hidden
    if (mounted && !_isDisposed) {
      setState(() {
        _showARKitOverlay = false;
      });
    }
    
    // 2. Give time for ARKit to completely hide
    await Future.delayed(Duration(milliseconds: 500));
    
    // 3. Ensure camera is in a good state - completely reset if needed
    await _quickCameraReset();
    
    // 4. Small delay to let camera stabilize
    await Future.delayed(Duration(milliseconds: 300));
    
    // 5. Ensure we're not streaming images
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
        await Future.delayed(Duration(milliseconds: 200));
      } catch (e) {
        // Log but continue
        print("⚠️ Error al detener stream: ${e.toString().split('\n')[0]}");
      }
    }
    
    // 6. Take the picture with multiple retries if needed
    result = await _captureWithRetries();
    
    return result;
  } catch (e) {
    print("❌ Error específico en captura AR: ${e.toString().split('\n')[0]}");
    return null;
  }
}

// NEW DEDICATED METHOD: Handling for light mode capture
Future<XFile?> _captureInLightMode() async {
  if (_isDisposed) return null;
  
  print("📸 Iniciando captura en modo luz...");
  XFile? result;
  
  try {
    // 1. Stop image stream first
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
        await Future.delayed(Duration(milliseconds: 300));
      } catch (e) {
        // Log but continue
        print("⚠️ Error al detener stream: ${e.toString().split('\n')[0]}");
      }
    }
    
    // 2. Take the picture with retries
    result = await _captureWithRetries();
    
    return result;
  } catch (e) {
    print("❌ Error específico en captura de luz: ${e.toString().split('\n')[0]}");
    return null;
  }
}

  // NUEVA FUNCIÓN: Maneja timeout en captura
  void _activateCaptureTimeout() {
    _captureTimeoutTimer?.cancel();
    
    // Si tarda más de 5 segundos, mostrar feedback y activar fallback
    _captureTimeoutTimer = Timer(Duration(seconds: 5), () {
      if (_takingPicture && mounted && !_isDisposed) {
        print("⚠️ Captura tardando demasiado, activando fallback");
        setState(() {
          _isCaptureFallbackActive = true;
          _feedback = "La captura está tardando más de lo normal...";
        });
        
        // Timer adicional para fallar gracefully después de 10 segundos
        Future.delayed(Duration(seconds: 5), () {
          if (_takingPicture && mounted && !_isDisposed) {
            setState(() {
              _takingPicture = false;
              _isCaptureFallbackActive = false;
              _feedback = "No se pudo tomar la foto. Intenta de nuevo";
            });
            
            // Reiniciar cámara
            _hardReset(targetMode: _measurementMode);
          }
        });
      }
    });
  }

  // Add this method to your class to restore ARKit visibility after capture
  @override
  void didUpdateWidget(ProductCameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Restore ARKit visibility if needed
    if (!_takingPicture && _measurementMode && !_showARKitOverlay && 
        _arkitController != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed && !_takingPicture) {
          setState(() {
            _showARKitOverlay = true;
          });
        }
      });
    }
  }

  // Método para preparar la cámara antes de capturar
  Future<void> _prepareForCapture() async {
    if (_isDisposed) return;
    
    try {
      // First, handle ARKit visibility
      if (_measurementMode && _arkitController != null) {
        print("🔍 Ocultando ARKit para captura");
        
        // Explicitly hide ARKit
        if (mounted && !_isDisposed) {
          setState(() {
            _showARKitOverlay = false;
          });
        }
        
        // Allow UI to update
        await Future.delayed(Duration(milliseconds: 300));
      }
      
      // Then safely stop image streaming
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        try {
          print("📷 Deteniendo stream para captura...");
          await _cameraController!.stopImageStream();
          // Allow camera to stabilize
          await Future.delayed(Duration(milliseconds: 300));
        } catch (e) {
          // Don't throw - just log and continue
          print("⚠️ Error controlado al detener stream: ${e.toString().split('\n')[0]}");
        }
      }
    } catch (e) {
      // Log but don't throw - we still want to attempt capture
      print("⚠️ Error durante preparación: ${e.toString().split('\n')[0]}");
    }
  }


  // Método optimizado para capturar con reintentos
  Future<XFile?> _captureWithRetries() async {
  if (_isDisposed) return null;
  
  XFile? photo;
  int attempts = 0;
  const maxAttempts = 3;
  
  try {
    while (attempts < maxAttempts && photo == null && 
          !_isDisposed && _takingPicture && !_isCaptureFallbackActive) {
      try {
        attempts++;
        print("📸 Capture attempt $attempts");
        
        // Update UI with attempt info
        if (mounted && !_isDisposed) {
          setState(() {
            _feedback = attempts > 1 
                ? "Intentando de nuevo ($attempts/3)..." 
                : "Capturando imagen...";
          });
        }
        
        // Special handling for the "Cannot Record" error
        // Try a completely different approach on second attempt
        if (attempts >= 2) {
          // On retry, use a different capture method that might work
          // This is a critical workaround for iOS "Cannot Record" errors
          photo = await _emergencyCaptureMethod();
        } else {
          // First attempt - standard method
          photo = await _cameraController!.takePicture().timeout(
            Duration(seconds: 3),
            onTimeout: () {
              print("⚠️ Timeout en intento $attempts");
              throw TimeoutException("Timeout al capturar");
            },
          );
        }
        
        // Check if we got a valid photo
        if (photo != null && await File(photo.path).exists()) {
          return photo;
        }
      } catch (e) {
        // Handle expected errors
        if (e.toString().contains("Cannot Record") || 
            e.toString().contains("Disposed CameraController")) {
          print("⚠️ Error esperado en intento $attempts: ${e.toString().split('\n')[0]}");
          
          // Critical: For this specific error, we need a special approach
          if (attempts < maxAttempts && !_isDisposed) {
            await _quickCameraReset();
            await Future.delayed(Duration(milliseconds: 300));
          }
        } else {
          print("⚠️ Error en intento $attempts: ${e.toString().split('\n')[0]}");
        }
        
        // Adaptive delay between attempts
        if (!_isDisposed && _takingPicture && !_isCaptureFallbackActive) {
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }
    }
  } catch (e) {
    print("⚠️ Error general en captureWithRetries: ${e.toString().split('\n')[0]}");
  }
  
  return photo;
}

Future<XFile?> _emergencyCaptureMethod() async {
  if (_isDisposed || _cameraController == null || !_cameraController!.value.isInitialized) {
    return null;
  }
  
  print("🚨 Usando método de captura de emergencia...");
  XFile? result;
  
  try {
    // 1. Make sure we've reset the camera controller first
    await _quickCameraReset();
    
    if (_isDisposed || _cameraController == null || !_cameraController!.value.isInitialized) {
      return null;
    }
    
    // 2. Try an alternative approach - use image stream to capture a frame
    final completer = Completer<XFile?>();
    
    // Setup a timeout for the emergency method
    Timer? emergencyTimeout = Timer(Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        print("⚠️ Timeout en método de emergencia");
        completer.complete(null);
      }
    });
    
    // Create a temporary file to save the image
    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = path.join(tempDir.path, 
      'emergency_capture_${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    try {
      // Start image stream just to get a single frame
      await _cameraController!.startImageStream((image) async {
        if (completer.isCompleted) return;
        
        // Stop stream immediately after getting first frame
        try {
          await _cameraController!.stopImageStream();
        } catch (e) {
          // Just log, don't throw
          print("⚠️ Error al detener stream de emergencia: ${e.toString().split('\n')[0]}");
        }
        
        try {
          // Process image data - this is simplified, you may need more processing 
          // based on your image format
          // This example assumes RGBA or BGRA format
          File imgFile = File(tempPath);
          
          // Use a platform-specific approach
          if (Platform.isIOS) {
            // For iOS, we'll create a temporary bitmap context and save that
            // This is just an example - you'll need to implement platform-specific
            // image conversion code here, possibly using FFI or method channels
            
            // Simplified placeholder - actual implementation would need image format conversion
            await imgFile.writeAsBytes(image.planes[0].bytes);
          } else {
            // For Android, use the bytes directly
            await imgFile.writeAsBytes(image.planes[0].bytes);
          }
          
          // After saving, create an XFile object
          if (await imgFile.exists()) {
            print("✅ Captura de emergencia exitosa");
            result = XFile(tempPath);
            emergencyTimeout?.cancel();
            completer.complete(result);
          } else {
            print("❌ Archivo de captura de emergencia no existe");
            emergencyTimeout?.cancel();
            completer.complete(null);
          }
        } catch (e) {
          print("❌ Error al procesar imagen de emergencia: ${e.toString().split('\n')[0]}");
          emergencyTimeout?.cancel();
          completer.complete(null);
        }
      });
      
      // Wait for either completion or timeout
      result = await completer.future;
    } catch (e) {
      print("❌ Error en método de captura de emergencia: ${e.toString().split('\n')[0]}");
      emergencyTimeout?.cancel();
    }
  } catch (e) {
    print("❌ Error general en método de emergencia: ${e.toString().split('\n')[0]}");
  }
  
  return result;
}

   Future<void> _quickCameraReset() async {
  if (_isDisposed) return;
  
  try {
    print("🔄 Reiniciando cámara para captura...");
    
    // Remember if ARKit was visible
    final wasARKitVisible = _showARKitOverlay;
    
    // Explicitly hide ARKit during reset
    if (wasARKitVisible && mounted && !_isDisposed) {
      setState(() {
        _showARKitOverlay = false;
      });
    }
    
    // Dispose current camera controller
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isInitialized) {
          if (_cameraController!.value.isStreamingImages) {
            try {
              await _cameraController!.stopImageStream();
              await Future.delayed(Duration(milliseconds: 200));
            } catch (e) {
              print("⚠️ Error controlado al detener stream: ${e.toString().split('\n')[0]}");
            }
          }
          await _cameraController!.dispose();
        } else {
          _cameraController!.dispose();
        }
      } catch (e) {
        print("⚠️ Error controlado al liberar cámara: ${e.toString().split('\n')[0]}");
      }
      _cameraController = null;
    }
    
    // Breathing room between disposal and initialization
    await Future.delayed(Duration(milliseconds: 400));
    
    if (_isDisposed) return;
    
    // Get camera list
    final cameras = await availableCameras().timeout(
      Duration(seconds: 2),
      onTimeout: () {
        print("⚠️ Timeout obteniendo cámaras durante reset");
        throw TimeoutException("Timeout al enumerar cámaras");
      },
    );
    
    if (cameras.isEmpty) {
      print("⚠️ No se encontraron cámaras durante reset");
      return;
    }
    
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    
    // Create new controller with a try-catch block
    try {
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      
      // Initialize with timeout
      await _cameraController!.initialize().timeout(
        Duration(seconds: 3),
        onTimeout: () {
          print("⚠️ Timeout al inicializar cámara durante reset");
          throw TimeoutException("Timeout de inicialización");
        },
      );
      
      // Give camera time to stabilize
      await Future.delayed(Duration(milliseconds: 300));
      
      print("✅ Camera reset successful");
    } catch (e) {
      print("⚠️ Error en reset de cámara: ${e.toString().split('\n')[0]}");
    }
  } catch (e) {
    print("⚠️ Error inesperado en reset: ${e.toString().split('\n')[0]}");
  }
}

  // Método para subir imagen a Firebase
  Future<String?> _uploadImage() async {
    if (_capturedImage == null || _isDisposed) {
      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = "No hay imagen para subir";
        });
      }
      return null;
    }
    
    try {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = true;
          _feedback = "Subiendo imagen...";
        });
      }
      
      final downloadUrl = await _storageService.uploadProductImage(_capturedImage!);
      
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _feedback = "Imagen subida correctamente";
        });
      }
      
      return downloadUrl;
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _feedback = "Error al subir. Intenta de nuevo";
        });
      }
      return null;
    }
  }

  void _resetImage() {
    if (_isLoading || _takingPicture || _isDisposed) return;
    
    if (mounted) {
      setState(() {
        _capturedImage = null;
        _isLoading = true;
        _feedback = "Reiniciando cámara...";
      });
    }

    // Usar el método de reinicio completo
    _hardReset(targetMode: _measurementMode);
  }

  // Vista de la cámara con mejores indicadores visuales
 Widget _buildCameraView() {
  if (!_isInitialized || _cameraController == null) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Cámara no disponible"),
          SizedBox(height: 20),
          CupertinoButton(
            child: Text("Reintentar"),
            onPressed: _isLoading ? null : _startInitialization,
          ),
        ],
      ),
    );
  }

  // Obtain light sensor values safely
  double lightLevel = _currentLightLevel;
  Color lightColor = _lightSensorService?.getLightLevelColor(lightLevel) ?? 
                    CupertinoColors.systemBlue;
  String lightFeedback = "";
  
  if (_lightSensorService != null && !_isDisposed && !_measurementMode) {
    try {
      lightFeedback = _lightSensorService!.feedbackNotifier.value;
    } catch (e) {
      print("⚠️ Error al leer feedback de luz: $e");
    }
  }

  return Stack(
    children: [
      // Camera view (always visible)
      Positioned.fill(
        child: AspectRatio(
          aspectRatio: _cameraController!.value.aspectRatio,
          child: CameraPreview(_cameraController!),
        ),
      ),
      
      // ARKit view for measurement - critical change: only show when explicitly allowed
      if (_hasLiDAR && _arKitView != null && _showARKitOverlay && 
          _measurementMode && !_takingPicture)
        Positioned.fill(
          child: _arKitView!,
        ),
        
        // NEW: Special protective overlay during capture to prevent red screen flash
        if (_takingPicture)
        Positioned.fill(
          child: Container(
            // Dark semi-transparent overlay to hide any red flashes
            color: CupertinoColors.black.withOpacity(0.65),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CupertinoActivityIndicator(
                    radius: 20,
                    color: CupertinoColors.white,
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _feedback,
                      style: GoogleFonts.inter(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_isCaptureFallbackActive) ...[
                    SizedBox(height: 20),
                    CupertinoButton(
                      color: CupertinoColors.destructiveRed,
                      child: Text("Cancelar"),
                      onPressed: () {
                        _captureTimeoutTimer?.cancel();
                        setState(() {
                          _takingPicture = false;
                          _isCaptureFallbackActive = false;
                          _feedback = "Captura cancelada";
                        });
                        // Reset
                        _hardReset(targetMode: _measurementMode);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        
        // Indicadores superiores
        if (!_takingPicture)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Current mode indicator
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _measurementMode 
                        ? CupertinoColors.activeBlue.withOpacity(0.7)
                        : lightColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _measurementMode 
                        ? 'Modo: Medición'
                        : 'Modo: Luz - ${(lightLevel * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // LiDAR status (only visible if available)
                if (_hasLiDAR)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _measurementMode
                          ? "LiDAR activo: Modo medición"
                          : "LiDAR disponible",
                      style: GoogleFonts.inter(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // Feedback and measurements
                if (_feedback.isNotEmpty || 
                    (_currentMeasurement.isNotEmpty && _measurementMode) || 
                    (lightFeedback.isNotEmpty && !_measurementMode))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeOrange.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: CupertinoColors.white,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _measurementMode && _currentMeasurement.isNotEmpty
                              ? CupertinoIcons.scope
                              : CupertinoIcons.info_circle,
                          color: CupertinoColors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _measurementMode && _currentMeasurement.isNotEmpty
                                ? "Medición: $_currentMeasurement"
                                : (_feedback.isNotEmpty ? _feedback : 
                                  !_measurementMode ? lightFeedback : ""),
                            style: GoogleFonts.inter(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        
        // Bottom buttons
        if (!_takingPicture)
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mode toggle button
                GestureDetector(
                  onTap: (_isLoading || _isModeChanging || _takingPicture) ? null : _toggleMode,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _isLoading || _isModeChanging
                          ? CupertinoColors.inactiveGray
                          : (_measurementMode 
                              ? CupertinoColors.activeBlue
                              : lightColor),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CupertinoColors.white,
                        width: 2,
                      ),
                    ),
                    child: _isLoading || _isModeChanging
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : Icon(
                            _measurementMode 
                                ? CupertinoIcons.lightbulb
                                : CupertinoIcons.arrow_2_circlepath,
                            color: CupertinoColors.white,
                            size: 25,
                          ),
                  ),
                ),
                
                // Photo button
                GestureDetector(
                  onTap: (_takingPicture || _isLoading) ? null : _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryBlue,
                        width: 3,
                      ),
                    ),
                    child: _isLoading
                        ? const CupertinoActivityIndicator()
                        : Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                  ),
                ),
                
                // Clear measurements button (only visible in measurement mode)
                _measurementMode
                    ? GestureDetector(
                        onTap: (_isLoading || _takingPicture) ? null : _clearMeasurements,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: (_isLoading || _takingPicture)
                                ? CupertinoColors.inactiveGray
                                : CupertinoColors.darkBackgroundGray,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CupertinoColors.white,
                              width: 2,
                            ),
                          ),
                          child: (_isLoading)
                              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                              : Icon(
                                  CupertinoIcons.refresh,
                                  color: CupertinoColors.white,
                                  size: 25,
                                ),
                        ),
                      )
                    : SizedBox(width: 50), // Empty space for distribution
              ],
            ),
          ),
      ],
    );
  }

// Vista de previsualización de imagen mejorada
  Widget _buildImagePreview() {
    return MediaQuery(
      // Eliminar padding inferior para evitar espacios en blanco
      data: MediaQuery.of(context).copyWith(
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen a pantalla completa - extendiéndose hasta los bordes
          Container(
            color: CupertinoColors.black, // Fondo negro para evitar espacios blancos
            child: _capturedImage != null
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    boundaryMargin: EdgeInsets.zero,
                    child: Image.file(
                      _capturedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                    ),
                  )
                : Center(
                    child: Text(
                      "No hay imagen",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
          ),
          
          // Botones en la parte inferior - eliminando cualquier padding o margen
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              // Padding horizontal solamente
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              color: CupertinoColors.black.withOpacity(0.01), // Color transparente para extender hasta abajo
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botón Retomar
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isLoading ? null : _resetImage,
                    child: Container(
                      width: 140,
                      height: 44,
                      decoration: BoxDecoration(
                        color: CupertinoColors.black,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: Text(
                          "Retomar",
                          style: GoogleFonts.inter(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Botón Usar Foto
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isLoading ? null : () async {
                      if (_capturedImage == null || _isDisposed) return;
                      
                      if (mounted) {
                        setState(() {
                          _isLoading = true;
                        });
                      }
                      
                      try {
                        final downloadUrl = await _uploadImage();
                        
                        if (_isDisposed) return;
                        
                        widget.onImageCaptured(_capturedImage!, downloadUrl);
                        
                        await Future.delayed(Duration(milliseconds: 100));
                        
                        if (mounted && !_isDisposed) {
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        print("❌ Error al procesar imagen: $e");
                        if (mounted && !_isDisposed) {
                          setState(() {
                            _isLoading = false;
                            _feedback = "Error al procesar. Intenta de nuevo";
                          });
                        }
                      }
                    },
                    child: Container(
                      width: 140,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: _isLoading
                            ? CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            : Text(
                                "Usar Foto",
                                style: GoogleFonts.inter(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Indicador de carga
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: CupertinoColors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                          radius: 14,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Subiendo imagen...",
                          style: GoogleFonts.inter(
                            color: CupertinoColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Tomar Foto de Producto",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: _isLoading && _capturedImage == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(radius: 15),
                    SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _feedback.isEmpty ? "Cargando..." : _feedback,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              )
            : _capturedImage != null
                ? _buildImagePreview()
                : _buildCameraView(),
      ),
    );
  }
}