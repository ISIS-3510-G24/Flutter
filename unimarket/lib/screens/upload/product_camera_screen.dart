import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:unimarket/models/measurement_model.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/services/firebase_storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:vector_math/vector_math_64.dart';
import 'package:collection/collection.dart';
import 'package:unimarket/services/light_sensor_service.dart';

class ProductCameraScreen extends StatefulWidget {
  final Function(File image, MeasurementData? measurementData) onImageCaptured;

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

  // Declarar esta variable de clase para almacenar el builder original de ErrorWidget.
  Widget Function(FlutterErrorDetails)? _oldErrorWidgetBuilder;

  List<MeasurementPoint> _measurementPoints = [];
  static const MethodChannel _channel = MethodChannel('your.package.name/file');
  List<MeasurementLine> _measurementLines = [];
  
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

  bool _showProgressBar = false;
  double _captureProgress = 0.0;
  Timer? _progressAnimationTimer;

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
    print("📸 Starting ProductCameraScreen");
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
  // Guardar el handler original
  _originalErrorHandler = FlutterError.onError;
  // Reemplazar con nuestro handler que suprime errores específicos
  FlutterError.onError = (FlutterErrorDetails details) {
    final String errorStr = details.exception.toString();
    if (errorStr.contains("Disposed CameraController") ||
        errorStr.contains("Cannot Record") ||
        errorStr.contains("buildPreview()") ||
        errorStr.contains("setState() called after dispose()")) {
      // Sólo loguear en consola sin notificar a la UI
      print("🛡️ Suppressed camera error: ${errorStr.split('\n')[0]}");
      return;
    }
    _originalErrorHandler?.call(details);
  };

  // Guardar el ErrorWidget.builder original
  _oldErrorWidgetBuilder = ErrorWidget.builder;
  // Sobrescribir el ErrorWidget.builder para evitar que se muestre el error en pantalla
  ErrorWidget.builder = (FlutterErrorDetails details) {
    final String errorStr = details.exceptionAsString();
    if (errorStr.contains("Disposed CameraController") ||
        errorStr.contains("buildPreview() was called on a disposed CameraController")) {
      // Retornamos un contenedor vacío en lugar de mostrar el error en la UI
      return Container();
    }
    return _oldErrorWidgetBuilder!(details);
  };

  print("🛡️ Camera error handler installed");
}

void _restoreErrorHandlers() {
  // Restaurar el handler original de FlutterError
  if (_isErrorHandlerOverridden && _originalErrorHandler != null) {
    FlutterError.onError = _originalErrorHandler;
    _isErrorHandlerOverridden = false;
    print("🛡️ Original error handler restored");
  }
  // Restaurar el ErrorWidget.builder original
  if (_oldErrorWidgetBuilder != null) {
    ErrorWidget.builder = _oldErrorWidgetBuilder!;
    print("🛡️ Original ErrorWidget.builder restored");
  }
}

  

  // NUEVA FUNCIÓN: Inicia la inicialización con un timeout de seguridad
  void _startInitialization() {
    _initializationTimer?.cancel();
    
    // Si tarda más de 8 segundos, mostrar un mensaje amigable
    _initializationTimer = Timer(Duration(seconds: 8), () {
      if (!_isInitialized && mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _feedback = "Initialization is taking longer than usual...";
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


 @override
  void dispose() {

    _progressAnimationTimer?.cancel();

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
        _feedback = "Initializing camera...";
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
          _feedback = _measurementMode ? "Measurement mode ready" : "Camera ready";
        });
      }
    } catch (e) {
      print("❌ Error al inicializar cámara: $e");
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _feedback = "Error initializing. Tap to retry";
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
          _feedback = "Camera not initialized";
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
            _feedback = "Light sensor mode activated";
          });
        }
      } catch (e) {
        print("⚠️ Error al iniciar stream: $e");
        if (mounted && !_isDisposed) {
          setState(() {
            _feedback = "Error with the sensor. Tap to retry";
          });
        }
      }
    } catch (e) {
      print("❌ Error en modo luz: $e");
      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = "Error in light mode. Tap to retry";
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
          _feedback = "LiDAR not available on this device";
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
          _feedback = "Measurement mode activated. Tap to measure";
          _showARKitOverlay = true;
        });
      }
    } catch (e) {
      print("❌ Error al iniciar modo medición: $e");
      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = "Error starting measurement";
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

  // Overlay mejorado para mostrar durante la captura
Widget _buildCaptureOverlay() {
  return Positioned.fill(
    child: Container(
      // Fondo oscuro para evitar destellos rojos y mostrar UI
      color: CupertinoColors.black.withOpacity(0.75),
      child: SafeArea(
        child: Column(
          children: [
            // Encabezado con información de captura
            Container(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              color: CupertinoColors.black.withOpacity(0.5),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.camera_fill,
                    color: CupertinoColors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Capturing image",
                      style: GoogleFonts.inter(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: CupertinoColors.systemGrey.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icono y mensaje para mantener el celular firme
                      if (_measurementMode)
                        Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.device_phone_portrait,
                                color: CupertinoColors.white,
                                size: 48,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Hold the phone steady",
                              style: GoogleFonts.inter(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Saving the measurements taken",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: CupertinoColors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 24),
                          ],
                        )
                      else
                        Column(
                          children: [
                            CupertinoActivityIndicator(
                              radius: 20,
                              color: CupertinoColors.white,
                            ),
                            SizedBox(height: 16),
                          ],
                        ),
                      
                      // Barra de progreso más atractiva para modo AR
                      if (_showProgressBar)
                        Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          margin: EdgeInsets.symmetric(vertical: 15),
                          child: Column(
                            children: [
                              // Texto de progreso
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  _captureProgress < 0.7 
                                      ? "Capturing image..." 
                                      : "Saving measurements...",
                                  style: GoogleFonts.inter(
                                    color: CupertinoColors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              // Contenedor para la barra de progreso
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: CupertinoColors.darkBackgroundGray,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Stack(
                                  children: [
                                    // Barra de progreso animada
                                    AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      curve: Curves.easeOut,
                                      width: MediaQuery.of(context).size.width * 0.6 * _captureProgress,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primaryBlue,
                                            AppColors.lightBlueAccent,
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryBlue.withOpacity(0.5),
                                            blurRadius: 6,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Efecto de brillo animado
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 2,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              CupertinoColors.white.withOpacity(0),
                                              CupertinoColors.white.withOpacity(0.5),
                                              CupertinoColors.white.withOpacity(0),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      SizedBox(height: 16),
                      
                      // Mensaje de feedback
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _feedback,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      
                      // Botón de cancelar para el fallback
                      if (_isCaptureFallbackActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: CupertinoButton(
                            color: CupertinoColors.destructiveRed,
                            child: Text("Cancel"),
                            onPressed: () {
                              _captureTimeoutTimer?.cancel();
                              _progressAnimationTimer?.cancel();
                              setState(() {
                                _takingPicture = false;
                                _isCaptureFallbackActive = false;
                                _showProgressBar = false;
                                _captureProgress = 0.0;
                                _feedback = "Capture canceled";
                              });
                              // Reset con método seguro
                              _safelyResetCamera();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // MÉTODO COMPLETAMENTE NUEVO: Reinicio completo para cambio de modo
 Future<void> _hardReset({required bool targetMode}) async {
  if (_isDisposed || _isModeChanging) return;
  
  _isModeChanging = true;
  
  if (mounted) {
    setState(() {
      _isLoading = true;
      _feedback = "Switching mode...";
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
        _feedback = "Error switching mode. Tap to retry";
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
        _feedback = "Tap to start measuring";
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

  // Create a sphere in the point touched
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
    
    // Store measurement point
    _measurementPoints.add(MeasurementPoint(position: position));
    print("📏 Added measurement point: ${position.x}, ${position.y}, ${position.z}");
  } catch (e) {
    print("⚠️ Error al añadir nodo: $e");
    return;
  }

  // If we already have a previous point, draw a line and record the measurement
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

      // Calculate and show the distance
      final distance = _calculateDistanceBetweenPoints(position, _lastPosition!);
      final midPoint = _getMiddleVector(position, _lastPosition!);
      _drawText(distance, midPoint);
      
      // Store measurement line
      _measurementLines.add(MeasurementLine(
        from: _lastPosition!,
        to: position,
        measurement: distance,
      ));
      print("📏 Added measurement line: $distance");
        
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
    
    // Clear stored measurement data
    _measurementPoints.clear();
    _measurementLines.clear();
    
    if (mounted && !_isDisposed) {
      setState(() {
        _currentMeasurement = '';
        _feedback = "Tap to start measuring";
      });
    }
  }

  // Método para animar suavemente la barra de progreso
void _startCaptureProgressAnimation(int duration, {double startFrom = 0.0}) {
  _progressAnimationTimer?.cancel();
  
  final int steps = 20; // Más pasos para una animación más suave
  final int stepDuration = duration ~/ steps;
  final double progressIncrement = (1.0 - startFrom) / steps;
  
  double currentProgress = startFrom;
  int currentStep = 0;
  
  _progressAnimationTimer = Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
    if (!mounted || _isDisposed) {
      timer.cancel();
      return;
    }
    
    currentStep++;
    
    // Usar una función easing para un movimiento más natural
    // (más lento al principio y al final, más rápido en el medio)
    final double easedProgress = _easeInOutCubic(currentStep / steps);
    currentProgress = startFrom + (easedProgress * (1.0 - startFrom));
    
    setState(() {
      _captureProgress = currentProgress.clamp(startFrom, 1.0);
    });
    
    if (currentStep >= steps) {
      timer.cancel();
    }
  });
}

// Función de easing para movimiento suave
double _easeInOutCubic(double t) {
  return t < 0.5
      ? 4 * t * t * t
      : 1 - pow(-2 * t + 2, 3) / 2;
}


// MÉTODO COMPLETO: _activateCaptureTimeout()
// Se elimina la actualización de _feedback_ para evitar que se muestre el mensaje de error en la UI.
void _activateCaptureTimeout() {
  _captureTimeoutTimer?.cancel();
  
  // Si la captura demora más de 5 segundos, se activa el fallback sin actualizar _feedback_
  _captureTimeoutTimer = Timer(Duration(seconds: 5), () {
    if (_takingPicture && mounted && !_isDisposed) {
      print("⚠️ Captura tardando demasiado, activando fallback");
      setState(() {
        _isCaptureFallbackActive = true;
        // Se omite actualizar _feedback_ para no mostrar mensaje visual en la UI
      });
      
      // Después de 5 segundos adicionales, si aún se está capturando, se reinicia la cámara sin mostrar error
      Future.delayed(Duration(seconds: 5), () {
        if (_takingPicture && mounted && !_isDisposed) {
          setState(() {
            _takingPicture = false;
            _isCaptureFallbackActive = false;
            _feedback = ""; // Se limpia el mensaje para que no se muestre nada
          });
          
          // Se reinicia la cámara con reset completo
          _hardReset(targetMode: _measurementMode);
        }
      });
    }
  });
}


// Updated _getImageInfo method to use safe file handling
Future<ui.Image> _getImageInfo(File imageFile) async {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  
  try {
    // Ensure we have a valid file
    if (!await imageFile.exists()) {
      throw Exception("Image file does not exist: ${imageFile.path}");
    }
    
    final data = await imageFile.readAsBytes();
    
    if (data.isEmpty) {
      throw Exception("Image data is empty");
    }
    
    ui.decodeImageFromList(data, (ui.Image img) {
      if (img.width == 0 || img.height == 0) {
        completer.completeError(Exception("Invalid image dimensions: ${img.width}x${img.height}"));
      } else {
        completer.complete(img);
      }
    });
  } catch (e) {
    print("❌ Error al decodificar imagen: $e");
    // Completar con un error en lugar de dejar el completer sin resolver
    completer.completeError(e);
  }
  
  return completer.future;
}

// Add this method to safely get image dimensions
Future<Size?> getSafeImageSize(File? imageFile) async {
  if (imageFile == null) return null;
  
  try {
    final ui.Image image = await _getImageInfo(imageFile);
    return Size(image.width.toDouble(), image.height.toDouble());
  } catch (e) {
    print("⚠️ Error getting image size: $e");
    return null;
  }
}

// NEW DEDICATED METHOD: Special handling for AR mode capture
Future<XFile?> _captureInARMode() async {
  if (_isDisposed) return null;
  
  print("📸 Iniciando captura en modo AR...");
  XFile? result;
  
  try {
    // 1. Hacer completamente invisible ARKit
    if (mounted && !_isDisposed) {
      setState(() {
        _showARKitOverlay = false;
        _feedback = "Preparing camera...";
      });
    }
    
    // 2. Tiempo significativo para que ARKit se oculte por completo
    await Future.delayed(Duration(milliseconds: 800));
    
    // 3. Reiniciar completamente la cámara con un nuevo enfoque más seguro
    final bool cameraReady = await _safelyResetCamera();
    
    // Si el reinicio falló, abortar captura
    if (!cameraReady || _cameraController == null || !_cameraController!.value.isInitialized) {
      print("⚠️ La cámara no está lista para capturar después del reinicio");
      throw Exception("Cámara no disponible para captura");
    }
    
    // 4. Esperar a que la cámara se estabilice
    await Future.delayed(Duration(milliseconds: 500));
    
    // 5. Verificar nuevamente estado de la cámara
    if (_isDisposed || _cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception("Cámara no disponible");
    }
    
    // 6. Capturar con múltiples reintentos si es necesario
    result = await _captureWithRetries();
    
    return result;
  } catch (e) {
    print("❌ Error específico en captura AR: ${e.toString().split('\n')[0]}");
    return null;
  }
}

Future<bool> _safelyResetCamera() async {
  if (_isDisposed) return false;
  
  try {
    print("🔄 Reiniciando cámara con método seguro...");
    
    // 1. Establecer bandera para indicar que estamos en proceso de reinicio
    bool _isResetting = true;
    
    // 2. Función interna para liberar recursos con seguridad
    Future<void> _safeReleaseCamera() async {
      try {
        // Primero intentar detener cualquier streaming
        if (_cameraController != null) {
          if (_cameraController!.value.isInitialized && _cameraController!.value.isStreamingImages) {
            try {
              print("📷 Deteniendo stream de cámara...");
              await _cameraController!.stopImageStream();
              await Future.delayed(Duration(milliseconds: 300));
            } catch (e) {
              print("⚠️ Error esperado al detener stream: ${e.toString().split('\n')[0]}");
              // Continuar aunque falle detener el stream
            }
          }
          
          // Luego intentar liberar el controlador
          try {
            print("📷 Liberando controlador de cámara...");
            await _cameraController!.dispose();
            await Future.delayed(Duration(milliseconds: 200));
          } catch (e) {
            print("⚠️ Error esperado al liberar cámara: ${e.toString().split('\n')[0]}");
            // Continuar aunque falle la liberación
          }
          
          // Siempre establecer a null después de intentar liberar
          _cameraController = null;
        }
      } catch (e) {
        print("⚠️ Error general al liberar cámara: ${e.toString().split('\n')[0]}");
        _cameraController = null;
      }
    }
    
    // 3. Liberar recursos actuales
    await _safeReleaseCamera();
    
    // 4. Pausa significativa para asegurar liberación completa
    await Future.delayed(Duration(milliseconds: 800));
    
    if (_isDisposed) return false;
    
    // 5. Obtener lista de cámaras con manejo de errores
    List<CameraDescription> cameras = [];
    try {
      print("📷 Obteniendo lista de cámaras...");
      cameras = await availableCameras().timeout(
        Duration(seconds: 3),
        onTimeout: () {
          print("⚠️ Timeout obteniendo cámaras");
          throw TimeoutException("Timeout al enumerar cámaras");
        },
      );
      
      if (cameras.isEmpty) {
        print("⚠️ No se encontraron cámaras disponibles");
        return false;
      }
      
      print("✅ Se encontraron ${cameras.length} cámaras");
    } catch (e) {
      print("❌ Error al obtener cámaras: ${e.toString().split('\n')[0]}");
      return false;
    }
    
    if (_isDisposed) return false;
    
    // 6. Seleccionar cámara trasera con validación
    CameraDescription? backCamera;
    try {
      backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      
      print("📷 Usando cámara: ${backCamera.name}");
    } catch (e) {
      print("⚠️ Error al seleccionar cámara: ${e.toString().split('\n')[0]}");
      if (cameras.isNotEmpty) {
        backCamera = cameras.first;
      } else {
        return false;
      }
    }
    
    if (_isDisposed) return false;
    
    // 7. Crear nuevo controlador con validación
    try {
      print("📷 Creando nuevo controlador de cámara...");
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      
      // Verificación extra
      if (_cameraController == null) {
        print("❌ Error: No se pudo crear controlador de cámara");
        return false;
      }
    } catch (e) {
      print("❌ Error al crear controlador: ${e.toString().split('\n')[0]}");
      return false;
    }
    
    if (_isDisposed) return false;
    
    // 8. Inicializar el controlador con retry y timeout
    bool initSuccess = false;
    int initAttempts = 0;
    
    while (!initSuccess && initAttempts < 2 && !_isDisposed) {
      try {
        initAttempts++;
        print("📷 Inicializando cámara (intento $initAttempts)...");
        
        await _cameraController!.initialize().timeout(
          Duration(seconds: 4),
          onTimeout: () {
            print("⚠️ Timeout al inicializar cámara");
            throw TimeoutException("Timeout de inicialización");
          },
        );
        
        // Si llegamos aquí, la inicialización fue exitosa
        initSuccess = true;
        print("✅ Cámara inicializada correctamente");
        
        // Esperar a que la cámara se estabilice
        await Future.delayed(Duration(milliseconds: 300));
      } catch (e) {
        print("⚠️ Error al inicializar cámara: ${e.toString().split('\n')[0]}");
        
        if (initAttempts < 2 && !_isDisposed) {
          // Liberar el controlador actual antes de reintentar
          await _safeReleaseCamera();
          await Future.delayed(Duration(milliseconds: 500));
          
          // Recrear el controlador para el siguiente intento
          if (!_isDisposed) {
            try {
              _cameraController = CameraController(
                backCamera,
                ResolutionPreset.high,
                enableAudio: false,
                imageFormatGroup: Platform.isIOS
                    ? ImageFormatGroup.bgra8888
                    : ImageFormatGroup.yuv420,
              );
            } catch (e) {
              print("❌ Error al recrear controlador: ${e.toString().split('\n')[0]}");
              return false;
            }
          }
        }
      }
    }
    
    _isResetting = false;
    return initSuccess && _cameraController != null && _cameraController!.value.isInitialized;
  } catch (e) {
    print("❌ Error inesperado en reset seguro: ${e.toString().split('\n')[0]}");
    return false;
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

Future<File> getFileFromPath(String filePath) async {
  // Si es un URI con esquema content://, usamos nuestro método de conversión
  if (filePath.startsWith('content://')) {
    try {
      return await _getFileFromContentUri(filePath);
    } catch (e) {
      print("❌ Error en getFileFromPath: $e. Se retorna archivo de respaldo.");
      // Devuelve un archivo vacío de respaldo para evitar propagar la excepción a la UI
      final Directory tempDir = await getTemporaryDirectory();
      final String tempFilePath = path.join(
        tempDir.path,
        'fallback_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final fallbackFile = File(tempFilePath);
      await fallbackFile.writeAsBytes([]);
      return fallbackFile;
    }
  } else {
    // Ruta normal, retornamos el archivo directamente
    return File(filePath);
  }
}

Future<File> _getFileFromContentUri(String contentPath) async {
  if (Platform.isAndroid) {
    try {
      // Se intenta obtener la ruta real mediante un método nativo vía MethodChannel.
      final String? realPath = await _channel.invokeMethod<String>(
        'getFilePathFromContentUri',
        {"uri": contentPath},
      );
      if (realPath != null && realPath.isNotEmpty) {
        return File(realPath);
      } else {
        print("⚠️ El método nativo retornó null o cadena vacía para el content URI.");
      }
    } catch (e) {
      print("❌ Error al invocar el método nativo para content URI: $e");
    }
    // Fallback: crear y retornar un archivo vacío para evitar que se propague la excepción.
    final Directory tempDir = await getTemporaryDirectory();
    final String tempFilePath = path.join(
      tempDir.path,
      'fallback_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final fallbackFile = File(tempFilePath);
    await fallbackFile.writeAsBytes([]);
    return fallbackFile;
  } else if (Platform.isIOS) {
    // En iOS, se puede intentar eliminar el prefijo "content://"
    final String fixedPath = contentPath.replaceFirst('content://', '');
    final File originalFile = File(fixedPath);
    if (await originalFile.exists()) {
      return originalFile;
    } else {
      throw Exception("Cannot access file from content URI on iOS");
    }
  } else {
    throw Exception("Unsupported platform");
  }
}

// Update this method to use the safe file handling
Future<XFile?> _captureWithRetries() async {
  if (_isDisposed) return null;
  
  XFile? photo;
  int attempts = 0;
  const maxAttempts = 3;
  
  try {
    while (attempts < maxAttempts && photo == null && 
          !_isDisposed && _takingPicture && !_isCaptureFallbackActive) {
      attempts++;
      print("📸 Capture attempt $attempts");
      
      // Actualizar UI con información de intento
      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = attempts > 1 
              ? "Retrying ($attempts/3)..." 
              : "Capturing image...";
        });
      }
      
      // Verificar que la cámara siga disponible
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        print("⚠️ Cámara no disponible en intento $attempts");
        
        if (attempts < maxAttempts) {
          // Si no es el último intento, tratar de reiniciarla
          bool reset = await _safelyResetCamera();
          if (!reset) {
            throw Exception("No se pudo reiniciar la cámara");
          }
          continue; // Ir al siguiente intento después del reinicio
        } else {
          throw Exception("Cámara no disponible después de múltiples intentos");
        }
      }
      
      try {
        // Capturar con método adaptativo
        if (attempts >= 2) {
          // En reintento, usar un método de captura de emergencia
          photo = await _emergencyCaptureMethod();
        } else {
          // Primer intento: método estándar con timeout
          photo = await _cameraController!.takePicture().timeout(
            Duration(seconds: 3),
            onTimeout: () {
              print("⚠️ Timeout en intento $attempts");
              throw TimeoutException("Timeout al capturar");
            },
          );
        }
        
        // Verificar si obtuvimos una foto válida
        if (photo != null) {
          try {
            // Use our new safe file handling method
            File photoFile = await getFileFromPath(photo.path);
            bool fileExists = await photoFile.exists();
            if (fileExists) {
              print("✅ Captura exitosa en intento $attempts");
              return photo;
            } else {
              print("⚠️ El archivo capturado no existe: ${photo.path}");
              photo = null; // Resetear para el siguiente intento
            }
          } catch (e) {
            print("⚠️ Error al verificar archivo: ${e.toString().split('\n')[0]}");
            photo = null; // Resetear para el siguiente intento
          }
        }
      } catch (e) {
        // Manejar errores específicos
        final String errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains("cannot record") || 
            errorMsg.contains("disposed") ||
            errorMsg.contains("null") ||
            errorMsg.contains("unsupported scheme")) {
          
          print("⚠️ Error esperado en intento $attempts: ${e.toString().split('\n')[0]}");
          
          // Para estos errores específicos, necesitamos reiniciar la cámara
          if (attempts < maxAttempts && !_isDisposed) {
            bool reset = await _safelyResetCamera();
            if (!reset) {
              print("⚠️ No se pudo reiniciar la cámara después de error");
            }
          }
        } else {
          print("⚠️ Error en intento $attempts: ${e.toString().split('\n')[0]}");
        }
        
        // Pausa adaptativa entre intentos
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
    // 1. Asegurarse de que la cámara está en un estado limpio
    await _safelyResetCamera();
    
    if (_isDisposed || _cameraController == null || !_cameraController!.value.isInitialized) {
      return null;
    }
    
    // 2. Crear archivo temporal para guardar la imagen
    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = path.join(tempDir.path, 
      'emergency_capture_${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    // 3. Capturar directamente con el método estándar pero con timeout corto
    try {
      result = await _cameraController!.takePicture().timeout(
        Duration(seconds: 2),
        onTimeout: () {
          print("⚠️ Timeout en método de emergencia");
          throw TimeoutException("Timeout en captura de emergencia");
        },
      );
      
      if (result != null) {
        print("✅ Captura de emergencia exitosa");
      }
    } catch (e) {
      print("❌ Error en captura de emergencia directa: ${e.toString().split('\n')[0]}");
      // Si falla el método directo, intentar un método aún más básico
      
      try {
        // Último recurso: tomar directamente la última imagen de la vista previa
        if (_cameraController != null && _cameraController!.value.isInitialized) {
          // Activar el flash para tener mejor iluminación si es posible
          try {
            await _cameraController!.setFlashMode(FlashMode.auto);
          } catch (e) {
            // Ignorar errores de flash
          }
          
          // Intentar capturar una imagen de la vista previa
          // Nota: Esta es una solución de último recurso
          result = await _cameraController!.takePicture();
        }
      } catch (e) {
        print("❌ Error en método de último recurso: ${e.toString().split('\n')[0]}");
      }
    }
  } catch (e) {
    print("❌ Error general en método de emergencia: ${e.toString().split('\n')[0]}");
  }
  
  return result;
}

// MÉTODO COMPLETO: _takePicture()
// Este método sigue utilizando _activateCaptureTimeout() para gestionar el timeout,
// pero como este ya no actualiza _feedback_, la UI no mostrará el error en rojo.
Future<void> _takePicture() async {
  if (_cameraController == null ||
      !_cameraController!.value.isInitialized ||
      _takingPicture ||
      _isLoading ||
      _isDisposed) {
    return;
  }

  // Inicia el timeout para la captura
  _activateCaptureTimeout();
  
  if (mounted && !_isDisposed) {
    setState(() {
      _takingPicture = true;
      _isCaptureFallbackActive = false;
      _feedback = _measurementMode 
          ? "Hold the phone steady..." 
          : "Preparing camera...";
      _showProgressBar = _measurementMode;
      _captureProgress = 0.0;
    });
  }

  // Guarda el modo actual
  final bool wasMeasurementMode = _measurementMode;
  
  try {
    // Pequeña pausa para actualizar la UI
    await Future.delayed(Duration(milliseconds: 300));
    
    // Si está en modo AR (medición) se muestra la animación de progreso
    if (wasMeasurementMode && mounted && !_isDisposed) {
      _startCaptureProgressAnimation(1500);
    }
    
    XFile? photo;
    
    if (wasMeasurementMode) {
      // Captura en modo AR
      photo = await _captureInARMode();
      
      if (mounted && !_isDisposed) {
        setState(() {
          _captureProgress = 0.7;
          _feedback = "Saving measurements...";
        });
      }
      
      _startCaptureProgressAnimation(800, startFrom: 0.7);
      
      await Future.delayed(Duration(milliseconds: 500));
    } else {
      // Captura estándar para modo luz
      photo = await _captureInLightMode();
    }
    
    // Cancelar el timeout en caso de éxito
    _captureTimeoutTimer?.cancel();
    
    if (photo == null) {
      throw Exception("No se pudo capturar la imagen");
    }
    
    print("✅ Foto capturada exitosamente: ${photo.path}");

    // Procesar la imagen con manejo de errores
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(appDir.path, fileName);

      print("💾 Guardando imagen en $filePath");
      
      final File sourceImage = await getFileFromPath(photo.path);
      
      if (!await sourceImage.exists()) {
        throw Exception("El archivo de origen no existe: ${photo.path}");
      }
      
      final File newFile = await sourceImage.copy(filePath)
          .timeout(Duration(seconds: 5), 
              onTimeout: () => throw TimeoutException("Timeout al guardar imagen"));
      
      if (!await newFile.exists()) {
        throw Exception("Fallo al guardar imagen en $filePath");
      }
      
      print("✅ Imagen guardada correctamente en $filePath");

      if (mounted && !_isDisposed) {
        setState(() {
          _capturedImage = newFile;
          _takingPicture = false;
          _isCaptureFallbackActive = false;
          _showProgressBar = false;
          _captureProgress = 0.0;
          _feedback = "Image captured successfully";
        });
      }
    } catch (e) {
      print("❌ Error al procesar imagen: ${e.toString().split('\n')[0]}");
      throw e;
    }
  } catch (e) {
    print("❌ Error en captura: ${e.toString().split('\n')[0]}");
    
    if (_isCaptureFallbackActive || _isDisposed) return;
    
    if (mounted && !_isDisposed) {
      setState(() {
        _takingPicture = false;
        _showProgressBar = false;
        _captureProgress = 0.0;
        _feedback = "Error taking photo. Try again";
      });
      
      // Reinicia la cámara usando el método seguro
      _safelyResetCamera().then((success) {
        if (success && mounted && !_isDisposed) {
          if (wasMeasurementMode != _measurementMode) {
            _toggleMode(); // Cambia al modo original si es necesario
          }
        } else {
          _hardReset(targetMode: wasMeasurementMode);
        }
      });
    }
  }
}

   Future<void> _quickCameraReset() async {
  if (_isDisposed) return;
  
  try {
    print("🔄 Reiniciando cámara para captura...");
    
    // Capturar el estado de ARKit antes de reiniciar
    final wasARKitVisible = _showARKitOverlay;
    
    // Ocultar ARKit durante el reinicio
    if (wasARKitVisible && mounted && !_isDisposed) {
      setState(() {
        _showARKitOverlay = false;
      });
    }
    
    // IMPORTANTE: Manejar con seguridad la liberación del controlador
    if (_cameraController != null) {
      try {
        // Primero detener el streaming si está activo
        if (_cameraController!.value.isInitialized && 
            _cameraController!.value.isStreamingImages) {
          try {
            await _cameraController!.stopImageStream();
            // Esperar un poco para que el stream se detenga completamente
            await Future.delayed(Duration(milliseconds: 200));
          } catch (e) {
            print("⚠️ Error controlado al detener stream: ${e.toString().split('\n')[0]}");
            // No propagamos el error, seguimos adelante
          }
        }
        
        // Luego intentar disponer el controlador
        if (_cameraController!.value.isInitialized) {
          try {
            await _cameraController!.dispose();
          } catch (e) {
            print("⚠️ Error controlado al liberar cámara inicializada: ${e.toString().split('\n')[0]}");
          }
        } else {
          try {
            _cameraController!.dispose();
          } catch (e) {
            print("⚠️ Error controlado al liberar cámara no inicializada: ${e.toString().split('\n')[0]}");
          }
        }
      } catch (e) {
        print("⚠️ Error general al liberar cámara: ${e.toString().split('\n')[0]}");
      } finally {
        // CRÍTICO: Asegurarnos de que el controlador se establece a null
        // independientemente de si hubo error o no
        _cameraController = null;
      }
    }
    
    // Pausa significativa entre liberar y crear un nuevo controlador
    await Future.delayed(Duration(milliseconds: 600));
    
    // Verificar si se ha dispuesto el widget
    if (_isDisposed) return;
    
    // Obtener lista de cámaras con manejo de errores
    List<CameraDescription> cameras = [];
    try {
      cameras = await availableCameras().timeout(
        Duration(seconds: 2),
        onTimeout: () {
          print("⚠️ Timeout obteniendo cámaras durante reset");
          throw TimeoutException("Timeout al enumerar cámaras");
        },
      );
    } catch (e) {
      print("⚠️ Error al obtener cámaras: ${e.toString().split('\n')[0]}");
      // Si no podemos obtener cámaras, no continuamos
      return;
    }
    
    if (cameras.isEmpty) {
      print("⚠️ No se encontraron cámaras durante reset");
      return;
    }
    
    // Seleccionar cámara trasera
    CameraDescription? backCamera;
    try {
      backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
    } catch (e) {
      print("⚠️ Error al seleccionar cámara: ${e.toString().split('\n')[0]}");
      if (cameras.isNotEmpty) {
        backCamera = cameras.first;
      } else {
        return; // No podemos continuar sin cámara
      }
    }
    
    // Crear e inicializar el nuevo controlador con protección completa
    if (!_isDisposed && backCamera != null) {
      try {
        // Crear nuevo controlador
        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: Platform.isIOS
              ? ImageFormatGroup.bgra8888
              : ImageFormatGroup.yuv420,
        );
        
        // Inicializar con timeout
        if (_cameraController != null) {
          await _cameraController!.initialize().timeout(
            Duration(seconds: 3),
            onTimeout: () {
              print("⚠️ Timeout al inicializar cámara durante reset");
              throw TimeoutException("Timeout de inicialización");
            },
          );
          
          // Tiempo para estabilizar la cámara
          await Future.delayed(Duration(milliseconds: 300));
          
          print("✅ Camera reset successful");
        }
      } catch (e) {
        print("⚠️ Error en reset de cámara: ${e.toString().split('\n')[0]}");
        // Si hay un error en la inicialización, establecer a null para evitar
        // errores futuros con un controlador en mal estado
        _cameraController = null;
      }
    }
  } catch (e) {
    print("⚠️ Error inesperado en reset: ${e.toString().split('\n')[0]}");
    // Asegurar que el controlador es null en caso de error
    _cameraController = null;
  }
}

  // Método para subir imagen a Firebase
  Future<String?> _uploadImage() async {
    if (_capturedImage == null || _isDisposed) {
      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = "No image to upload";
        });
      }
      return null;
    }
    
    try {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = true;
          _feedback = "Uploading image...";
        });
      }
      
      final downloadUrl = await _storageService.uploadProductImage(_capturedImage!);
      
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _feedback = "Image uploaded successfully";
        });
      }
      
      return downloadUrl;
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _feedback = "Error uploading. Try again";
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
        _feedback = "Restarting camera...";
      });
    }

    // Usar el método de reinicio completo
    _hardReset(targetMode: _measurementMode);
  }

// MÉTODO COMPLETO: _buildCameraView()_ con spinner personalizado y canvas
Widget _buildCameraView() {
  // Si el controlador de cámara es nulo o no está inicializado…
  if (_cameraController == null || !_cameraController!.value.isInitialized) {
    // Si se está cargando, cambiando modo o tomando foto, mostrar spinner personalizado.
    if (_isLoading || _isModeChanging || _takingPicture) {
      return Center(
        child: CustomSpinner(size: 50),
      );
    }
    
    // Si no estamos en modo de carga, mostramos un contenedor con mensaje de error y botón de reintento.
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: CupertinoColors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: CupertinoColors.systemYellow,
              size: 40,
            ),
            SizedBox(height: 16),
            Text(
              "Camera not available",
              style: GoogleFonts.inter(
                color: CupertinoColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _feedback.isEmpty ? "Please try again" : _feedback,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: CupertinoColors.white,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 20),
            CupertinoButton(
              color: AppColors.primaryBlue,
              child: Text("Retry"),
              onPressed: _isLoading ? null : _startInitialization,
            ),
          ],
        ),
      ),
    );
  }
  
  // Cuando el controlador está inicializado, mostramos la vista completa.
  double lightLevel = _currentLightLevel;
  Color lightColor = _lightSensorService?.getLightLevelColor(lightLevel) ?? CupertinoColors.systemBlue;
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
      // Vista de cámara
      Positioned.fill(
        child: AspectRatio(
          aspectRatio: _cameraController!.value.aspectRatio,
          child: CameraPreview(_cameraController!),
        ),
      ),
      
      // Vista ARKit para medición (solo si está activada y disponible)
      if (_hasLiDAR && _arKitView != null && _showARKitOverlay && _measurementMode && !_takingPicture)
        Positioned.fill(child: _arKitView!),
      
      // Overlay durante la captura
      if (_takingPicture)
        _buildCaptureOverlay(),
      
      // Indicadores y feedback en la parte superior
      if (!_takingPicture)
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _measurementMode 
                      ? CupertinoColors.activeBlue.withOpacity(0.7)
                      : lightColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _measurementMode 
                      ? 'Mode: Measurement'
                      : 'Mode: Light - ${(lightLevel * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_hasLiDAR)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _measurementMode
                        ? "LiDAR active: Measurement mode"
                        : "LiDAR available",
                    style: GoogleFonts.inter(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
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
                              ? "Measurement: $_currentMeasurement"
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
      
      // Botones inferiores
      if (!_takingPicture)
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botón de cambio de modo
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
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLoading || _isModeChanging
                      ? CupertinoActivityIndicator(color: CupertinoColors.white)
                      : Icon(
                          _measurementMode 
                              ? CupertinoIcons.lightbulb
                              : CupertinoIcons.arrow_2_circlepath,
                          color: CupertinoColors.white,
                          size: 25,
                        ),
                ),
              ),
              
              // Botón de foto
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
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? CupertinoActivityIndicator()
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
              
              // Botón para limpiar mediciones (solo en modo medición)
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
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black.withOpacity(0.2),
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: (_isLoading)
                            ? CupertinoActivityIndicator(color: CupertinoColors.white)
                            : Icon(
                                CupertinoIcons.refresh,
                                color: CupertinoColors.white,
                                size: 25,
                              ),
                      ),
                    )
                  : SizedBox(width: 50),
            ],
          ),
        ),
    ],
  );
}

Widget _buildImagePreview() {
  final Size screenSize = MediaQuery.of(context).size;
  
  return Container(
    color: CupertinoColors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Imagen simplificada sin FutureBuilder
        if (_capturedImage != null)
          Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: screenSize.width,
                maxHeight: screenSize.height * 0.7,
              ),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  _capturedImage!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            color: CupertinoColors.systemYellow,
                            size: 40,
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Error displaying image",
                            style: GoogleFonts.inter(
                              color: CupertinoColors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          )
        else
          Center(
            child: Text(
              "No image available",
              style: GoogleFonts.inter(
                color: CupertinoColors.white,
                fontSize: 16,
              ),
            ),
          ),

        // Measurement info overlay (only in measurement mode with measurements)
        if (_measurementMode && _measurementLines.isNotEmpty)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Measurement count badge
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeBlue.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: CupertinoColors.white,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${_measurementLines.length} measurements saved',
                    style: GoogleFonts.inter(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // List the first 3 measurements (if available)
                if (_measurementLines.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: CupertinoColors.systemGrey6,
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Captured measurements:",
                          style: GoogleFonts.inter(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 5),
                        ..._measurementLines
                            .take(3) // Only show first 3 measurements
                            .map((line) => Container(
                                  margin: EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.scope,
                                        color: CupertinoColors.activeBlue,
                                        size: 14,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        line.measurement,
                                        style: GoogleFonts.inter(
                                          color: CupertinoColors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        if (_measurementLines.length > 3)
                          Text(
                            "... and ${_measurementLines.length - 3} more",
                            style: GoogleFonts.inter(
                              color: CupertinoColors.systemGrey,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
        // Bottom buttons
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  CupertinoColors.black,
                  CupertinoColors.black.withOpacity(0.7),
                  CupertinoColors.black.withOpacity(0),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Retomar button
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isLoading ? null : _resetImage,
                  child: Container(
                    width: 140,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CupertinoColors.darkBackgroundGray,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: CupertinoColors.systemGrey,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.camera,
                            color: CupertinoColors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Retake",
                            style: GoogleFonts.inter(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Usar Foto button
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isLoading ? null : () async {
                    if (_capturedImage == null || _isDisposed) return;
                    
                    setState(() {
                      _isLoading = true;
                      _feedback = "Preparing image...";
                    });
                    
                    try {
                      // Create measurement data if in measurement mode and there are measurements
                      MeasurementData? measurementData;
                      if (_measurementMode && (_measurementPoints.isNotEmpty || _measurementLines.isNotEmpty)) {
                        measurementData = MeasurementData(
                          points: List.from(_measurementPoints),
                          lines: List.from(_measurementLines),
                        );
                        print("✅ Preparando ${_measurementLines.length} medidas con la imagen");
                      } else {
                        print("⚠️ No hay medidas para guardar con la imagen");
                      }
                      
                      // Call the callback with local file and measurement data
                      widget.onImageCaptured(_capturedImage!, measurementData);
                      
                      // Short delay to show the success message
                      if (mounted && !_isDisposed) {
                        setState(() {
                          _isLoading = false;
                          _feedback = "Image ready!";
                        });
                      }
                      
                      await Future.delayed(Duration(milliseconds: 500));
                      
                      // Pop back to the upload screen
                      if (mounted && !_isDisposed) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      print("❌ Error al procesar imagen: $e");
                      if (mounted && !_isDisposed) {
                        setState(() {
                          _isLoading = false;
                          _feedback = "Error processing. Try again";
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
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.check_mark,
                                  color: CupertinoColors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Use Photo",
                                  style: GoogleFonts.inter(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Loading overlay
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: CupertinoColors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.systemGrey,
                      width: 1,
                    ),
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
                        _feedback.isEmpty ? "Processing..." : _feedback,
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
          "Take Product Photo",
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
                        _feedback.isEmpty ? "Loading..." : _feedback,
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

// Spinner personalizado usando canvas
class CustomSpinner extends StatefulWidget {
  final double size;
  const CustomSpinner({Key? key, this.size = 50.0}) : super(key: key);

  @override
  _CustomSpinnerState createState() => _CustomSpinnerState();
}

class _CustomSpinnerState extends State<CustomSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: 1))..repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          painter: _SpinnerPainter(),
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = CupertinoColors.activeBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final double radius = size.width / 2;
    // Dibujar un arco de 270 grados (3/4 de círculo)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(radius, radius), radius: radius),
      0,
      3 * pi / 2,
      false,
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}