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
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
import 'package:vector_math/vector_math_64.dart';
import 'package:collection/collection.dart';
import 'package:unimarket/services/light_sensor_service.dart';

class ProductCameraScreen extends StatefulWidget {
  final Function(File image, MeasurementData? measurementData) onImageCaptured;
  const ProductCameraScreen({Key? key, required this.onImageCaptured})
      : super(key: key);

  @override
  _ProductCameraScreenState createState() => _ProductCameraScreenState();
}

class _ProductCameraScreenState extends State<ProductCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  ARKitController? _arkitController;
  FirebaseStorageService _storageService = FirebaseStorageService();
  LightSensorService? _lightSensorService;

  // Handler para errores
  Widget Function(FlutterErrorDetails)? _oldErrorWidgetBuilder;

  List<MeasurementPoint> _measurementPoints = [];
  static const MethodChannel _channel =
      MethodChannel('your.package.name/file');
  List<MeasurementLine> _measurementLines = [];

  bool _arkitFullyInitialized = false;
  double _arkitCoverOpacity = 1.0;

  bool _isInitialized = false;
  String _initializingMode = "";
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

  bool _arkitInitializing = false;
  bool _arkitReady = false;

  bool _showProgressBar = false;
  double _captureProgress = 0.0;
  Timer? _progressAnimationTimer;

  FlutterExceptionHandler? _originalErrorHandler;
  bool _isErrorHandlerOverridden = false;

  Timer? _captureTimeoutTimer;
  Timer? _modeChangeTimer;
  Timer? _initializationTimer;

  String _feedback = '';
  DateTime? _lastLightUpdate;
  double _currentLightLevel = 0.5;

  Vector3? _lastPosition;
  List<ARKitNode> _measurementNodes = [];
  String _currentMeasurement = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupErrorHandlers();
    _lightSensorService = LightSensorService();
    _feedback = '';
    _lastPosition = null;
    _currentMeasurement = '';
    _measurementNodes = [];
    _measurementMode = false;
    _isDisposed = false;
    _initializingMode = "light";
    _startInitialization();
    Future.delayed(Duration(milliseconds: 2000), () {
      if (!_isDisposed && _hasLiDAR && _arKitView == null) {
        _preloadARKit();
      }
    });
  }

  void _preloadARKit() {
    if (_arKitView != null || _isDisposed || !_hasLiDAR) return;
    try {
      _arKitView = ARKitSceneView(
        onARKitViewCreated: (controller) {
          _arkitController = controller;
          Future.delayed(Duration(milliseconds: 1000), () {
            if (!_isDisposed) {
              _arkitReady = true;
              _arkitInitializing = false;
            }
          });
          controller.onARTap = (List<ARKitTestResult> ar) {
            if (_isDisposed || _takingPicture || _isModeChanging) return;
            final ARKitTestResult? point = ar.firstWhereOrNull(
                (o) => o.type == ARKitHitTestResultType.featurePoint);
            if (point != null) _onARTapHandler(point);
          };
        },
        configuration: ARKitConfiguration.worldTracking,
        enableTapRecognizer: true,
        planeDetection: ARPlaneDetection.horizontal,
      );
    } catch (e) {

    }
  }

  void _setupErrorHandlers() {
    _originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final String errorStr = details.exception.toString();
      if (errorStr.contains("Disposed CameraController") ||
          errorStr.contains("Cannot Record") ||
          errorStr.contains("buildPreview()") ||
          errorStr.contains("setState() called after dispose()")) {
        return;
      }
      _originalErrorHandler?.call(details);
    };
    _oldErrorWidgetBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      final String errorStr = details.exceptionAsString();
      if (errorStr.contains("Disposed CameraController") ||
          errorStr.contains("buildPreview() was called on a disposed CameraController"))
        return Container();
      return _oldErrorWidgetBuilder!(details);
    };
  }

  void _restoreErrorHandlers() {
    if (_isErrorHandlerOverridden && _originalErrorHandler != null) {
      FlutterError.onError = _originalErrorHandler;
      _isErrorHandlerOverridden = false;
    }
    if (_oldErrorWidgetBuilder != null) {
      ErrorWidget.builder = _oldErrorWidgetBuilder!;
    }
  }

  

  void _startInitialization() {
    _initializationTimer?.cancel();
    _initializationTimer = Timer(Duration(seconds: 8), () {
      if (!_isInitialized && mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _feedback = "Initialization is taking longer than usual...";
        });
        _cleanupResources(fullCleanup: false);
        _initializeCamera();
      }
    });
    _initializeCamera();
  }

  void _initializeARKit() {
    try {
      if (_arKitView != null) return;
      _arkitInitializing = true;
      if (mounted) {
        setState(() {
          _feedback = "Preparing LiDAR...";
          _showARKitOverlay = false;
        });
      }
      _arKitView = ARKitSceneView(
        onARKitViewCreated: (controller) {
          _arkitController = controller;
          Future.delayed(Duration(milliseconds: 1000), () {
            if (mounted && !_isDisposed && _measurementMode) {
              setState(() {
                _arkitInitializing = false;
                _showARKitOverlay = true;
                _feedback = "Tap to start measuring";
              });
            }
          });
          controller.onARTap = (List<ARKitTestResult> ar) {
            if (_isDisposed || _takingPicture || _isModeChanging) return;
            final ARKitTestResult? point = ar.firstWhereOrNull(
                (o) => o.type == ARKitHitTestResultType.featurePoint);
            if (point != null) _onARTapHandler(point);
          };
        },
        configuration: ARKitConfiguration.worldTracking,
        enableTapRecognizer: true,
        planeDetection: ARPlaneDetection.horizontal,
      );

    } catch (e) {

      _feedback = "Error al inicializar LiDAR";
      _arkitInitializing = false;
      _measurementMode = false;
    }
  }

  @override
  void dispose() {
    _progressAnimationTimer?.cancel();
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _restoreErrorHandlers();
    _captureTimeoutTimer?.cancel();
    _modeChangeTimer?.cancel();
    _initializationTimer?.cancel();
    _cleanupResources(fullCleanup: true);
    super.dispose();
  }

  Future<void> _cleanupResources({bool fullCleanup = false}) async {
    try {
      _captureTimeoutTimer?.cancel();
      _modeChangeTimer?.cancel();
      if (_cameraController != null) {
        if (_cameraController!.value.isInitialized) {
          if (_cameraController!.value.isStreamingImages) {
            try {
              await _cameraController!.stopImageStream();
              await Future.delayed(Duration(milliseconds: 200));
            } catch (e) {

            }
          }
          try {
            await _cameraController!.dispose();
            _cameraController = null;
          } catch (e) {

            _cameraController = null;
          }
        } else {
          try {
            _cameraController!.dispose();
            _cameraController = null;
          } catch (e) {

            _cameraController = null;
          }
        }
      }
      if (_arkitController != null) {
        try {
          _arkitController!.dispose();
          _arkitController = null;
        } catch (e) {

          _arkitController = null;
        }
      }
      if (!fullCleanup) _arKitView = null;
      if (fullCleanup && _lightSensorService != null) {
        try {
          _lightSensorService!.dispose();
          _lightSensorService = null;
        } catch (e) {

        }
      }
      _measurementNodes.clear();
      _lastPosition = null;
      await Future.delayed(Duration(milliseconds: 100));
    } catch (e) {

    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cleanupResources(fullCleanup: false);
    } else if (state == AppLifecycleState.resumed) {
      _isInitialized = false;
      _startInitialization();
    }
  }

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
      _hasLiDAR = await _checkLiDARSupport();

      final cameras = await availableCameras().timeout(
        Duration(seconds: 3),
        onTimeout: () {

          throw TimeoutException("No se detectaron cámaras");
        },
      );
      if (cameras.isEmpty) throw Exception("No se encontraron cámaras disponibles");
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize().timeout(
        Duration(seconds: 4),
        onTimeout: () {
          throw TimeoutException("Timeout inicializando cámara");
        },
      );
      if (_hasLiDAR && _arKitView == null) _initializeARKit();
      await Future.delayed(Duration(milliseconds: 200));
      if (_measurementMode && _hasLiDAR) {
        await _startMeasurementMode();
      } else {
        _measurementMode = false;
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

      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _feedback = "Error initializing. Tap to retry";
        });
      }
    }
  }
Future<void> _startLightMode() async {
  _initializingMode = "light";
  if (_isDisposed) return;
  
  // Esta es la línea que falta - iniciar el stream de imágenes para analizar luz
  if (_cameraController != null && _cameraController!.value.isInitialized) {
    try {
      await _cameraController!.startImageStream((CameraImage image) {
        _processCameraImage(image);
      });
      if (mounted) setState(() {
        _feedback = "Light sensor active";
      });
    } catch (e) {
      print("Error starting image stream: $e");
      if (mounted) setState(() {
        _feedback = "Error activating light sensor";
      });
    }
  }
  
  _initializingMode = "";
}

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
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
          await Future.delayed(Duration(milliseconds: 300));
        } catch (e) {

        }
      }
      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = "Starting measurement mode...";
          _measurementMode = true;
          _showARKitOverlay = false;
        });
      }
      if (_arKitView == null) {
        _arkitInitializing = true;
        _initializeARKit();
      } else {
        _arkitInitializing = true;
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed) {
            setState(() {
              _arkitInitializing = false;
              _showARKitOverlay = true;
              _feedback = "Tap to start measuring";
            });
          }
        });
      }
    } catch (e) {

      if (mounted && !_isDisposed) {
        setState(() {
          _feedback = "Error starting measurement";
          _measurementMode = false;
          _showARKitOverlay = false;
          _arkitInitializing = false;
        });
      }
      if (!_isDisposed) {
        Future.delayed(Duration(milliseconds: 500), () {
          if (!_isDisposed) _startLightMode();
        });
      }
    }
  }

  Widget _buildCaptureOverlay() {
    return Positioned.fill(
      child: Container(
        color: CupertinoColors.black.withOpacity(0.75),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                color: CupertinoColors.black.withOpacity(0.5),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.camera_fill, color: CupertinoColors.white, size: 24),
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
                        if (_measurementMode)
                          Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(CupertinoIcons.device_phone_portrait,
                                    color: CupertinoColors.white, size: 48),
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
                              CupertinoActivityIndicator(radius: 20, color: CupertinoColors.white),
                              SizedBox(height: 16),
                            ],
                          ),
                        if (_showProgressBar)
                          Container(
                            width: MediaQuery.of(context).size.width * 0.6,
                            margin: EdgeInsets.symmetric(vertical: 15),
                            child: Column(
                              children: [
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
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.darkBackgroundGray,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Stack(
                                    children: [
                                      AnimatedContainer(
                                        duration: Duration(milliseconds: 200),
                                        curve: Curves.easeOut,
                                        width: MediaQuery.of(context).size.width *
                                            0.6 *
                                            _captureProgress,
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

  Future<void> _hardReset({required bool targetMode}) async {
    if (_isDisposed || _isModeChanging) return;
    _isModeChanging = true;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _feedback = "Switching mode...";
        _showARKitOverlay = false;
      });
    }
    try {
      await _cleanupResources(fullCleanup: false);
      _measurementMode = targetMode;
      _isInitialized = false;
      await Future.delayed(Duration(milliseconds: 800));
      if (!_isDisposed) await _initializeCamera();
    } catch (e) {

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

  Future<void> _toggleMode() async {
    if (_isLoading || _isModeChanging || _isDisposed || _takingPicture) return;
    _arkitInitializing = false;
    _arkitReady = false;
    _showARKitOverlay = false;
    await _hardReset(targetMode: !_measurementMode);
  }

  Future<bool> _checkLiDARSupport() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;

      final String model = iosInfo.modelName;
      final bool hasLiDAR = model.contains('iPhone 12 Pro') ||
          model.contains('iPhone 13 Pro') ||
          model.contains('iPhone 14 Pro') ||
          model.contains('iPhone 15 Pro') ||
          (model.contains('iPad Pro') &&
              int.tryParse(model.split(' ').last) != null &&
              int.parse(model.split(' ').last) >= 2020);


      return hasLiDAR;
    } catch (e) {

      return false;
    }
  }

  void _processCameraImage(CameraImage image) {
    if (_isDisposed ||
        _lightSensorService == null ||
        _takingPicture ||
        _isModeChanging) return;
    final now = DateTime.now();
    if (_lastLightUpdate != null &&
        now.difference(_lastLightUpdate!).inMilliseconds < 500) return;
    _lastLightUpdate = now;
    try {
      _lightSensorService!.processCameraImage(image);
      if (mounted && !_isDisposed) {
        setState(() {
          try {
            _currentLightLevel =
                _lightSensorService!.lightLevelNotifier.value;
            _feedback = _lightSensorService!.feedbackNotifier.value;
          } catch (e) {

          }
        });
      }
    } catch (e) {

    }
  }

  void _onARKitViewCreated(ARKitController controller) {

    _arkitController = controller;
    Future.delayed(Duration(milliseconds: 1000), () {
      if (mounted && !_isDisposed && _arkitController != null)
        print("🔍 ARKit session initialized");
    });
    controller.onARTap = (List<ARKitTestResult> ar) {
      if (_isDisposed || _takingPicture || _isModeChanging) return;
      final ARKitTestResult? point = ar.firstWhereOrNull(
          (o) => o.type == ARKitHitTestResultType.featurePoint);
      if (point != null) _onARTapHandler(point);
    };
  }

  void _onARTapHandler(ARKitTestResult point) {
    if (_arkitController == null ||
        _isDisposed ||
        _takingPicture ||
        _isModeChanging) return;
    final position = Vector3(
      point.worldTransform.getColumn(3).x,
      point.worldTransform.getColumn(3).y,
      point.worldTransform.getColumn(3).z,
    );
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
      _measurementPoints.add(MeasurementPoint(position: position));

    } catch (e) {

      return;
    }
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
        final distance =
            _calculateDistanceBetweenPoints(position, _lastPosition!);
        final midPoint = _getMiddleVector(position, _lastPosition!);
        _drawText(distance, midPoint);
        _measurementLines.add(MeasurementLine(
          from: _lastPosition!,
          to: position,
          measurement: distance,
        ));

        if (mounted && !_isDisposed) {
          setState(() {
            _currentMeasurement = distance;
          });
        }
      } catch (e) {

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

    }
  }

  void _clearMeasurements() {
    if (_arkitController == null || _isDisposed) return;
    _lastPosition = null;
    for (final node in _measurementNodes) {
      try {
        _arkitController?.remove(node.name);
      } catch (e) {

      }
    }
    _measurementNodes.clear();
    _measurementPoints.clear();
    _measurementLines.clear();
    if (mounted && !_isDisposed) {
      setState(() {
        _currentMeasurement = '';
        _feedback = "Tap to start measuring";
      });
    }
  }

  void _startCaptureProgressAnimation(int duration, {double startFrom = 0.0}) {
    _progressAnimationTimer?.cancel();
    final int steps = 20;
    final int stepDuration = duration ~/ steps;
    final double progressIncrement = (1.0 - startFrom) / steps;
    double currentProgress = startFrom;
    int currentStep = 0;
    _progressAnimationTimer =
        Timer.periodic(Duration(milliseconds: stepDuration), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }
      currentStep++;
      final double easedProgress = _easeInOutCubic(currentStep / steps);
      currentProgress = startFrom + (easedProgress * (1.0 - startFrom));
      setState(() {
        _captureProgress = currentProgress.clamp(startFrom, 1.0);
      });
      if (currentStep >= steps) timer.cancel();
    });
  }

  double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
  }

  void _activateCaptureTimeout() {
    _captureTimeoutTimer?.cancel();
    _captureTimeoutTimer = Timer(Duration(seconds: 5), () {
      if (_takingPicture && mounted && !_isDisposed) {

        setState(() {
          _isCaptureFallbackActive = true;
        });
        Future.delayed(Duration(seconds: 5), () {
          if (_takingPicture && mounted && !_isDisposed) {
            setState(() {
              _takingPicture = false;
              _isCaptureFallbackActive = false;
              _feedback = "";
            });
            _hardReset(targetMode: _measurementMode);
          }
        });
      }
    });
  }

  Future<ui.Image> _getImageInfo(File imageFile) async {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    try {
      if (!await imageFile.exists())
        throw Exception("Image file does not exist: ${imageFile.path}");
      final data = await imageFile.readAsBytes();
      if (data.isEmpty) throw Exception("Image data is empty");
      ui.decodeImageFromList(data, (ui.Image img) {
        if (img.width == 0 || img.height == 0)
          completer.completeError(Exception(
              "Invalid image dimensions: ${img.width}x${img.height}"));
        else
          completer.complete(img);
      });
    } catch (e) {

      completer.completeError(e);
    }
    return completer.future;
  }

  Future<Size?> getSafeImageSize(File? imageFile) async {
    if (imageFile == null) return null;
    try {
      final ui.Image image = await _getImageInfo(imageFile);
      return Size(image.width.toDouble(), image.height.toDouble());
    } catch (e) {

      return null;
    }
  }

  Future<XFile?> _captureInARMode() async {
    if (_isDisposed) return null;

    XFile? result;
    try {
      if (mounted && !_isDisposed) {
        setState(() {
          _showARKitOverlay = false;
          _feedback = "Preparing camera...";
        });
      }
      await Future.delayed(Duration(milliseconds: 800));
      final bool cameraReady = await _safelyResetCamera();
      if (!cameraReady ||
          _cameraController == null ||
          !_cameraController!.value.isInitialized) {

        throw Exception("Cámara no disponible para captura");
      }
      await Future.delayed(Duration(milliseconds: 500));
      if (_isDisposed ||
          _cameraController == null ||
          !_cameraController!.value.isInitialized)
        throw Exception("Cámara no disponible");
      result = await _captureWithRetries();
      return result;
    } catch (e) {

      return null;
    }
  }

  Future<bool> _safelyResetCamera() async {
    if (_isDisposed) return false;
    try {

      bool _isResetting = true;
      Future<void> _safeReleaseCamera() async {
        try {
          if (_cameraController != null) {
            if (_cameraController!.value.isInitialized &&
                _cameraController!.value.isStreamingImages) {
              try {

                await _cameraController!.stopImageStream();
                await Future.delayed(Duration(milliseconds: 300));
              } catch (e) {
                print(
                    "⚠️ Error esperado al detener stream: ${e.toString().split('\n')[0]}");
              }
            }
            try {

              await _cameraController!.dispose();
              await Future.delayed(Duration(milliseconds: 200));
            } catch (e) {
              print(
                  "⚠️ Error esperado al liberar cámara: ${e.toString().split('\n')[0]}");
            }
            _cameraController = null;
          }
        } catch (e) {
          print(
              "⚠️ Error general al liberar cámara: ${e.toString().split('\n')[0]}");
          _cameraController = null;
        }
      }
      await _safeReleaseCamera();
      await Future.delayed(Duration(milliseconds: 800));
      if (_isDisposed) return false;
      List<CameraDescription> cameras = [];
      try {

        cameras = await availableCameras().timeout(
          Duration(seconds: 3),
          onTimeout: () {

            throw TimeoutException("Timeout al enumerar cámaras");
          },
        );
        if (cameras.isEmpty) {

          return false;
        }

      } catch (e) {

        return false;
      }
      if (_isDisposed) return false;
      CameraDescription? backCamera;
      try {
        backCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );

      } catch (e) {

        if (cameras.isNotEmpty) backCamera = cameras.first;
        else return false;
      }
      if (_isDisposed) return false;
      try {

        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: Platform.isIOS
              ? ImageFormatGroup.bgra8888
              : ImageFormatGroup.yuv420,
        );
        if (_cameraController == null) {

          return false;
        }
      } catch (e) {

        return false;
      }
      if (_isDisposed) return false;
      bool initSuccess = false;
      int initAttempts = 0;
      while (!initSuccess && initAttempts < 2 && !_isDisposed) {
        try {
          initAttempts++;

          await _cameraController!.initialize().timeout(
            Duration(seconds: 4),
            onTimeout: () {

              throw TimeoutException("Timeout de inicialización");
            },
          );
          initSuccess = true;

          await Future.delayed(Duration(milliseconds: 300));
        } catch (e) {

          if (initAttempts < 2 && !_isDisposed) {
            await _safeReleaseCamera();
            await Future.delayed(Duration(milliseconds: 500));
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

                return false;
              }
            }
          }
        }
      }
      _isResetting = false;
      return initSuccess &&
          _cameraController != null &&
          _cameraController!.value.isInitialized;
    } catch (e) {

      return false;
    }
  }

  Future<XFile?> _captureInLightMode() async {
    if (_isDisposed) return null;

    XFile? result;
    try {
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
          await Future.delayed(Duration(milliseconds: 300));
        } catch (e) {

        }
      }
      result = await _captureWithRetries();
      return result;
    } catch (e) {

      return null;
    }
  }

  @override
  void didUpdateWidget(ProductCameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_takingPicture &&
        _measurementMode &&
        !_showARKitOverlay &&
        _arkitController != null &&
        mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed && !_takingPicture) {
          setState(() {
            _showARKitOverlay = true;
          });
        }
      });
    }
  }

  Future<void> _prepareForCapture() async {
    if (_isDisposed) return;
    try {
      if (_measurementMode && _arkitController != null) {

        if (mounted && !_isDisposed) {
          setState(() {
            _showARKitOverlay = false;
          });
        }
        await Future.delayed(Duration(milliseconds: 300));
      }
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        try {

          await _cameraController!.stopImageStream();
          await Future.delayed(Duration(milliseconds: 300));
        } catch (e) {

        }
      }
    } catch (e) {

    }
  }

  Future<File> getFileFromPath(String filePath) async {
    if (filePath.startsWith('content://')) {
      try {
        return await _getFileFromContentUri(filePath);
      } catch (e) {

        final Directory tempDir = await getTemporaryDirectory();
        final String tempFilePath =
            path.join(tempDir.path, 'fallback_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final fallbackFile = File(tempFilePath);
        await fallbackFile.writeAsBytes([]);
        return fallbackFile;
      }
    } else {
      return File(filePath);
    }
  }

  Future<File> _getFileFromContentUri(String contentPath) async {
    if (Platform.isAndroid) {
      try {
        final String? realPath = await _channel.invokeMethod<String>(
            'getFilePathFromContentUri', {"uri": contentPath});
        if (realPath != null && realPath.isNotEmpty) {
          return File(realPath);
        } else {

        }
      } catch (e) {

      }
      final Directory tempDir = await getTemporaryDirectory();
      final String tempFilePath =
          path.join(tempDir.path, 'fallback_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final fallbackFile = File(tempFilePath);
      await fallbackFile.writeAsBytes([]);
      return fallbackFile;
    } else if (Platform.isIOS) {
      final String fixedPath = contentPath.replaceFirst('content://', '');
      final File originalFile = File(fixedPath);
      if (await originalFile.exists()) return originalFile;
      else throw Exception("Cannot access file from content URI on iOS");
    } else {
      throw Exception("Unsupported platform");
    }
  }

  Future<XFile?> _captureWithRetries() async {
    if (_isDisposed) return null;
    XFile? photo;
    int attempts = 0;
    const maxAttempts = 3;
    try {
      while (attempts < maxAttempts &&
          photo == null &&
          !_isDisposed &&
          _takingPicture &&
          !_isCaptureFallbackActive) {
        attempts++;

        if (mounted && !_isDisposed) {
          setState(() {
            _feedback = attempts > 1
                ? "Retrying ($attempts/3)..."
                : "Capturing image...";
          });
        }
        if (_cameraController == null ||
            !_cameraController!.value.isInitialized) {

          if (attempts < maxAttempts) {
            bool reset = await _safelyResetCamera();
            if (!reset) throw Exception("No se pudo reiniciar la cámara");
            continue;
          } else {
            throw Exception(
                "Cámara no disponible después de múltiples intentos");
          }
        }
        try {
          if (attempts >= 2) {
            photo = await _emergencyCaptureMethod();
          } else {
            photo = await _cameraController!.takePicture().timeout(
              Duration(seconds: 3),
              onTimeout: () {

                throw TimeoutException("Timeout al capturar");
              },
            );
          }
          if (photo != null) {
            try {
              File photoFile = await getFileFromPath(photo.path);
              bool fileExists = await photoFile.exists();
              if (fileExists) {

                return photo;
              } else {

                photo = null;
              }
            } catch (e) {

              photo = null;
            }
          }
        } catch (e) {
          final String errorMsg = e.toString().toLowerCase();
          if (errorMsg.contains("cannot record") ||
              errorMsg.contains("disposed") ||
              errorMsg.contains("null") ||
              errorMsg.contains("unsupported scheme")) {

            if (attempts < maxAttempts && !_isDisposed) {
              bool reset = await _safelyResetCamera();
              if (!reset) print("⚠️ No se pudo reiniciar la cámara después de error");
            }
          } else {

          }
          if (!_isDisposed && _takingPicture && !_isCaptureFallbackActive)
            await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }
    } catch (e) {

    }
    return photo;
  }

  Future<XFile?> _emergencyCaptureMethod() async {
    if (_isDisposed ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return null;
    }

    XFile? result;
    try {
      await _safelyResetCamera();
      if (_isDisposed ||
          _cameraController == null ||
          !_cameraController!.value.isInitialized) return null;
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = path.join(
          tempDir.path, 'emergency_capture_${DateTime.now().millisecondsSinceEpoch}.jpg');
      try {
        result = await _cameraController!.takePicture().timeout(
          Duration(seconds: 2),
          onTimeout: () {

            throw TimeoutException("Timeout en captura de emergencia");
          },
        );
        if (result != null) print("✅ Captura de emergencia exitosa");
      } catch (e) {

        try {
          if (_cameraController != null &&
              _cameraController!.value.isInitialized) {
            try {
              await _cameraController!.setFlashMode(FlashMode.auto);
            } catch (e) {}
            result = await _cameraController!.takePicture();
          }
        } catch (e) {

        }
      }
    } catch (e) {

    }
    return result;
  }

  Future<void> _takePicture() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _takingPicture ||
        _isLoading ||
        _isDisposed) return;
    _activateCaptureTimeout();
    if (mounted && !_isDisposed) {
      setState(() {
        _takingPicture = true;
        _isCaptureFallbackActive = false;
        _feedback =
            _measurementMode ? "Hold the phone steady..." : "Preparing camera...";
        _showProgressBar = _measurementMode;
        _captureProgress = 0.0;
      });
    }
    final bool wasMeasurementMode = _measurementMode;
    try {
      await Future.delayed(Duration(milliseconds: 300));
      if (wasMeasurementMode && mounted && !_isDisposed)
        _startCaptureProgressAnimation(1500);
      XFile? photo;
      if (wasMeasurementMode) {
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
        photo = await _captureInLightMode();
      }
      _captureTimeoutTimer?.cancel();
      if (photo == null) throw Exception("No se pudo capturar la imagen");

      try {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String fileName =
            'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String filePath = path.join(appDir.path, fileName);

        final File sourceImage = await getFileFromPath(photo.path);
        if (!await sourceImage.exists())
          throw Exception("El archivo de origen no existe: ${photo.path}");
        final File newFile = await sourceImage.copy(filePath).timeout(
            Duration(seconds: 5),
            onTimeout: () =>
                throw TimeoutException("Timeout al guardar imagen"));
        if (!await newFile.exists())
          throw Exception("Fallo al guardar imagen en $filePath");

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

        throw e;
      }
    } catch (e) {

      if (_isCaptureFallbackActive || _isDisposed) return;
      if (mounted && !_isDisposed) {
        setState(() {
          _takingPicture = false;
          _showProgressBar = false;
          _captureProgress = 0.0;
          _feedback = "Error taking photo. Try again";
        });
        _safelyResetCamera().then((success) {
          if (success && mounted && !_isDisposed) {
            if (wasMeasurementMode != _measurementMode) {
              _toggleMode();
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

      final wasARKitVisible = _showARKitOverlay;
      if (wasARKitVisible && mounted && !_isDisposed) {
        setState(() {
          _showARKitOverlay = false;
        });
      }
      if (_cameraController != null) {
        try {
          if (_cameraController!.value.isInitialized &&
              _cameraController!.value.isStreamingImages) {
            try {
              await _cameraController!.stopImageStream();
              await Future.delayed(Duration(milliseconds: 200));
            } catch (e) {

            }
          }
          if (_cameraController!.value.isInitialized) {
            try {
              await _cameraController!.dispose();
            } catch (e) {

            }
          } else {
            try {
              _cameraController!.dispose();
            } catch (e) {

            }
          }
        } catch (e) {

        } finally {
          _cameraController = null;
        }
      }
      await Future.delayed(Duration(milliseconds: 600));
      if (_isDisposed) return;
      List<CameraDescription> cameras = [];
      try {
        cameras = await availableCameras().timeout(
          Duration(seconds: 2),
          onTimeout: () {

            throw TimeoutException("Timeout al enumerar cámaras");
          },
        );
      } catch (e) {

        return;
      }
      if (cameras.isEmpty) {

        return;
      }
      CameraDescription? backCamera;
      try {
        backCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
      } catch (e) {

        if (cameras.isNotEmpty) backCamera = cameras.first;
        else return;
      }
      if (!_isDisposed && backCamera != null) {
        try {
          _cameraController = CameraController(
            backCamera,
            ResolutionPreset.high,
            enableAudio: false,
            imageFormatGroup: Platform.isIOS
                ? ImageFormatGroup.bgra8888
                : ImageFormatGroup.yuv420,
          );
          if (_cameraController != null) {
            await _cameraController!.initialize().timeout(
              Duration(seconds: 3),
              onTimeout: () {

                throw TimeoutException("Timeout de inicialización");
              },
            );
            await Future.delayed(Duration(milliseconds: 300));

          }
        } catch (e) {

          _cameraController = null;
        }
      }
    } catch (e) {

      _cameraController = null;
    }
  }

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
    _hardReset(targetMode: _measurementMode);
  }

  Widget _buildCameraView() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      if (_isLoading || _isModeChanging || _takingPicture)
        return Center(child: CustomSpinner(size: 50));
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
              Icon(CupertinoIcons.exclamationmark_triangle,
                  color: CupertinoColors.systemYellow, size: 40),
              SizedBox(height: 16),
              Text(
                "Camera not available",
                style: GoogleFonts.inter(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              SizedBox(height: 12),
              Text(
                _feedback.isEmpty ? "Please try again" : _feedback,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.inter(color: CupertinoColors.white, fontSize: 14),
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
    double lightLevel = _currentLightLevel;
    Color lightColor =
        _lightSensorService?.getLightLevelColor(lightLevel) ?? CupertinoColors.systemBlue;
    String lightFeedback = "";
    if (_lightSensorService != null && !_isDisposed && !_measurementMode) {
      try {
        lightFeedback = _lightSensorService!.feedbackNotifier.value;
      } catch (e) {

      }
    }
    return Stack(
      children: [
        if (_measurementMode &&
            _arkitInitializing &&
            !_takingPicture &&
            _initializingMode == "measurement")
          Positioned.fill(
            child: Container(
              color: CupertinoColors.black.withOpacity(0.4),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(
                        radius: 20, color: CupertinoColors.white),
                    SizedBox(height: 16),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: CupertinoColors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Initializing LiDAR...",
                        style: GoogleFonts.inter(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),
        if (_measurementMode &&
            _arkitInitializing &&
            !_takingPicture)
          Positioned.fill(
            child: Container(
              color: CupertinoColors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoActivityIndicator(
                        radius: 20, color: CupertinoColors.white),
                    SizedBox(height: 16),
                    Text(
                      "Initializing measurement tools...",
                      style: GoogleFonts.inter(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_hasLiDAR &&
            _arKitView != null &&
            _showARKitOverlay &&
            _measurementMode &&
            !_takingPicture)
          Positioned.fill(child: _arKitView!),
        if (_takingPicture) _buildCaptureOverlay(),
        if (!_takingPicture)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _measurementMode
                        ? CupertinoColors.activeBlue.withOpacity(0.7)
                        : lightColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: CupertinoColors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    _measurementMode
                        ? 'Mode: Measurement'
                        : 'Mode: Light - ${(lightLevel * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_hasLiDAR)
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: CupertinoColors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      _measurementMode
                          ? "LiDAR active: Measurement mode"
                          : "LiDAR available",
                      style: GoogleFonts.inter(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_feedback.isNotEmpty ||
                    (_currentMeasurement.isNotEmpty && _measurementMode) ||
                    (lightFeedback.isNotEmpty && !_measurementMode))
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeOrange.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: CupertinoColors.white, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                            color: CupertinoColors.black.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _measurementMode &&
                                  _currentMeasurement.isNotEmpty
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
                                : (_feedback.isNotEmpty
                                    ? _feedback
                                    : !_measurementMode
                                        ? lightFeedback
                                        : ""),
                            style: GoogleFonts.inter(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
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
        if (!_takingPicture)
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: (_isLoading || _isModeChanging || _takingPicture)
                      ? null
                      : _toggleMode,
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
                            offset: Offset(0, 2)),
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
                            offset: Offset(0, 3)),
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
                _measurementMode
                    ? GestureDetector(
                        onTap:
                            (_isLoading || _takingPicture) ? null : _clearMeasurements,
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
                                  offset: Offset(0, 2)),
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
                          color: CupertinoColors.white, radius: 14),
                      SizedBox(height: 12),
                      Text(
                        _feedback.isEmpty ? "Processing..." : _feedback,
                        style: GoogleFonts.inter(
                            color: CupertinoColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
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
                            Icon(CupertinoIcons.exclamationmark_triangle,
                                color: CupertinoColors.systemYellow, size: 40),
                            SizedBox(height: 12),
                            Text(
                              "Error displaying image",
                              style: GoogleFonts.inter(
                                  color: CupertinoColors.white, fontSize: 16),
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
                    color: CupertinoColors.white, fontSize: 16),
              ),
            ),
          if (_measurementMode && _measurementLines.isNotEmpty)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: CupertinoColors.white, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                            color: CupertinoColors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      '${_measurementLines.length} measurements saved',
                      style: GoogleFonts.inter(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_measurementLines.isNotEmpty)
                    Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                              offset: Offset(0, 3)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Captured measurements:",
                            style: GoogleFonts.inter(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          SizedBox(height: 5),
                          ..._measurementLines
                              .take(3)
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
                                              fontSize: 14),
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
                                  fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
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
                            Icon(CupertinoIcons.camera,
                                color: CupertinoColors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Retake",
                              style: GoogleFonts.inter(
                                  color: CupertinoColors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_capturedImage == null || _isDisposed) return;
                            setState(() {
                              _isLoading = true;
                              _feedback = "Preparing image...";
                            });
                            try {
                              MeasurementData? measurementData;
                              if (_measurementMode &&
                                  (_measurementPoints.isNotEmpty ||
                                      _measurementLines.isNotEmpty)) {
                                measurementData = MeasurementData(
                                  points: List.from(_measurementPoints),
                                  lines: List.from(_measurementLines),
                                );
                                print(
                                    "✅ Preparando ${_measurementLines.length} medidas con la imagen");
                              } else {

                              }
                              widget.onImageCaptured(_capturedImage!, measurementData);
                              if (mounted && !_isDisposed) {
                                setState(() {
                                  _isLoading = false;
                                  _feedback = "Image ready!";
                                });
                              }
                              await Future.delayed(Duration(milliseconds: 500));
                              if (mounted && !_isDisposed) {
                                Navigator.of(context).pop();
                              }
                            } catch (e) {

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
                              offset: Offset(0, 3)),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? CupertinoActivityIndicator(
                                color: CupertinoColors.white)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.check_mark,
                                      color: CupertinoColors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    "Use Photo",
                                    style: GoogleFonts.inter(
                                        color: CupertinoColors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16),
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
                            color: CupertinoColors.white, radius: 14),
                        SizedBox(height: 12),
                        Text(
                          _feedback.isEmpty ? "Processing..." : _feedback,
                          style: GoogleFonts.inter(
                              color: CupertinoColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500),
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
        middle: Text("Take Product Photo",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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

class CustomSpinner extends StatefulWidget {
  final double size;
  const CustomSpinner({Key? key, this.size = 50.0}) : super(key: key);

  @override
  _CustomSpinnerState createState() => _CustomSpinnerState();
}

class _CustomSpinnerState extends State<CustomSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: Duration(seconds: 1))..repeat();
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
