import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/services/firebase_storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:vector_math/vector_math_64.dart';

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
  CameraController? _cameraController;
  ARKitController? _arkitController;
  FirebaseStorageService _storageService = FirebaseStorageService();

  bool _isInitialized = false;
  bool _isLoading = true;
  bool _hasLiDAR = false;
  bool _takingPicture = false;
  bool _isProcessingImage = false;
  // Controla si se muestra el overlay de ARKit
  bool _showARKitOverlay = true;
  File? _capturedImage;
  Widget? _arKitView;

  // Variables para sensores
  double? _distanceToObject;
  double _lightLevel = 0.5;
  String _feedback = '';

  // Throttling: para limitar actualizaciones de luz y LiDAR
  DateTime? _lastLightUpdate;
  DateTime? _lastLidarUpdate;

  // Temporizador para mediciones periódicas (ARKit)
  Timer? _measurementTimer;

  @override
  void initState() {
    super.initState();
    print("Iniciando ProductCameraScreen - comprobando ARKit y LiDAR");
    WidgetsBinding.instance.addObserver(this);

    Timer.periodic(Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      print("== VERIFICACIÓN PERIÓDICA DE ARKIT ==");
      print("ARKit controller: ${_arkitController != null}");
      print("Distancia actual: $_distanceToObject");
      print("Feedback actual: $_feedback");
      print("hasLiDAR: $_hasLiDAR");
    });

    _initializeCamera();
  }

  void _initializeARKit() {
    _arKitView ??= ARKitSceneView(
        onARKitViewCreated: _onARKitViewCreated,
        configuration: ARKitConfiguration.worldTracking,
        planeDetection: ARPlaneDetection.horizontal,
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _measurementTimer?.cancel();

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.stopImageStream().then((_) {
        _cameraController!.dispose();
      }).catchError((e) {
        print("Error al detener flujo de imágenes: $e");
        _cameraController!.dispose();
      });
    } else if (_cameraController != null) {
      _cameraController!.dispose();
    }

    try {
      _arkitController?.dispose();
    } catch (e) {
      print("Error al liberar ARKitController: $e");
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      _measurementTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      if (_hasLiDAR && _arkitController == null) {
        _initializeARKit();
      }
    }
  }

  Future<void> _initializeCamera() async {
    _isLoading = true;
    if (mounted) setState(() {});

    try {
      // Verificar soporte de LiDAR
      _hasLiDAR = await _checkLiDARSupport();
      print("LiDAR detectado: $_hasLiDAR");

      if (_hasLiDAR) {
        print("Antes de cargar AR");
        _initializeARKit();
        print("Despues de cargar AR");

        _measurementTimer =
            Timer.periodic(Duration(milliseconds: 500), (timer) {
          _performPeriodicMeasurement();
        });
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _feedback = "No cameras found";
        _isLoading = false;
        if (mounted) setState(() {});
        return;
      }

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

      await _cameraController!.initialize();

  
      if (_cameraController!.value.isInitialized) {
        await _cameraController!.startImageStream(_processCameraImage);
      }

      _isInitialized = true;
      _isLoading = false;
      if (mounted) setState(() {});
    } catch (e) {
      print("Error completo al inicializar la cámara: $e");
      _feedback = "Error initializing camera: $e";
      _isLoading = false;
      if (mounted) setState(() {});
    }
  }

  Future<bool> _checkLiDARSupport() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;

      print("Modelo de dispositivo: ${iosInfo.model}");
      print("Todos los detalles del dispositivo: ${iosInfo.toString()}");

      final String model = iosInfo.modelName;

      final bool hasLiDAR = model.contains('iPhone 12 Pro') ||
          model.contains('iPhone 13 Pro') ||
          model.contains('iPhone 14 Pro') ||
          model.contains('iPhone 15 Pro') ||
          (model.contains('iPad Pro') &&
              int.tryParse(model.split(' ').last) != null &&
              int.parse(model.split(' ').last) >= 2020);

      print("¿Dispositivo compatible con LiDAR según modelo? $hasLiDAR");
      print("Modelo detectado: $model");

      return hasLiDAR;
    } catch (e) {
      print("Error detallado al verificar soporte LiDAR: $e");
      return false;
    }
  }

  void _processCameraImage(CameraImage image) {
    // Throttling para sensor de luz: procesa solo cada 100 ms
    final now = DateTime.now();
    if (_lastLightUpdate != null &&
        now.difference(_lastLightUpdate!) < Duration(milliseconds: 1000)) {
      return;
    }
    _lastLightUpdate = now;

    if (image.planes.isEmpty || _isProcessingImage || !mounted) return;
    _isProcessingImage = true;

    try {
      double averageLuminance = 0.0;
      int count = 0;

      if (image.format.group == ImageFormatGroup.yuv420) {
        final plane = image.planes[0];
        for (int i = 0; i < plane.bytes.length; i += 10) {
          averageLuminance += plane.bytes[i];
          count++;
        }
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        final plane = image.planes[0];
        // Se muestrea cada 10 píxeles (cada píxel ocupa 4 bytes)
        for (int i = 0; i < plane.bytes.length; i += 40) {
          int b = plane.bytes[i];
          int g = plane.bytes[i + 1];
          int r = plane.bytes[i + 2];
          int brightness = ((r + g + b) ~/ 3);
          averageLuminance += brightness;
          count++;
        }
      }

      if (count > 0) {
        averageLuminance = averageLuminance / count;
      }
      final double normalizedLightLevel = averageLuminance / 255.0;

      if (mounted) {
        setState(() {
          _lightLevel = normalizedLightLevel;
          // Actualiza feedback del sensor de luz
          if (normalizedLightLevel < 0.2) {
            _feedback = "Too dark, add more light";
          } else if (normalizedLightLevel > 0.8) {
            _feedback = "Too bright, reduce light";
          } else {
            _feedback = "Good lighting";
          }
        });
      }
    } catch (e) {
      print("Error processing camera image: $e");
    } finally {
      _isProcessingImage = false;
    }
  }

  void _onARKitViewCreated(ARKitController controller) {
    print("ARKit controller creado - esperando detección de planos");
    print("_hasLiDAR: $_hasLiDAR");
    _arkitController = controller;

    if (mounted) {
      setState(() {
        _feedback = "Apunta a una superficie plana cercana";
      });
    }

    print("ARKit controller inicializado correctamente");

    try {
      print("ARKit configurado para detección de planos cercanos");
    } catch (e) {
      print("Error en configuración inicial de ARKit: $e");
    }

    try {
      controller.onAddNodeForAnchor = (ARKitAnchor anchor) {
        print("ARKit: Se detectó una ancla de tipo: ${anchor.runtimeType}");
        if (anchor is ARKitPlaneAnchor) {
          try {
            _updateDistanceFeedback(anchor);
            if (mounted) {
              setState(() {
                _feedback =
                    "Superficie detectada a ${_distanceToObject?.toStringAsFixed(2)}m";
              });
            }
            _addPlaneNode(anchor);
          } catch (e) {
            print("Error al procesar plano detectado: $e");
          }
        }
      };

      controller.onUpdateNodeForAnchor = (ARKitAnchor anchor) {
        try {
          if (anchor is ARKitPlaneAnchor && mounted) {
            _updateDistanceFeedback(anchor);
          }
        } catch (e) {
          print("Error al actualizar plano: $e");
        }
      };

      controller.onError = (dynamic error) {
        print("Error de ARKit: $error");
        if (mounted) {
          setState(() {
            _feedback = "Error de ARKit: $error";
          });
        }
      };
    } catch (e) {
      print("Error al configurar callbacks de ARKit: $e");
    }
  }

  void _performPeriodicMeasurement() {
    // Throttling para LiDAR: procesa solo cada 500 ms
    final now = DateTime.now();
    if (_lastLidarUpdate != null &&
        now.difference(_lastLidarUpdate!) < Duration(milliseconds: 500)) {
      return;
    }
    _lastLidarUpdate = now;

    if (_arkitController == null || !mounted) return;

    try {
      _arkitController!.performHitTest(x: 0.5, y: 0.5).then((results) {
        if (results.isNotEmpty) {
          final hitResult = results.first;
          final distance = hitResult.worldTransform.getColumn(3).z.abs();

          if (mounted) {
            setState(() {
              _distanceToObject = distance;
              if (distance < 0.3) {
                _feedback = "Demasiado cerca del objeto";
              } else if (distance > 1.5) {
                _feedback = "Acércate más al objeto";
              } else {
                _feedback = "¡Distancia perfecta! Puedes tomar la foto";
              }
            });
          }
        }
      }).catchError((e) {
        print("Error en hitTest: $e");
      });
    } catch (e) {
      print("Error en medición periódica: $e");
    }
  }

  void _updateDistanceFeedback(ARKitPlaneAnchor anchor) {
    try {
      final Vector4 column = anchor.transform.getColumn(3);
      final double distance = column.z.abs();

      if (distance > 0 && distance < 5.0 && mounted) {
        setState(() {
          _distanceToObject = distance;
          if (distance < 0.3) {
            _feedback = "Demasiado cerca del objeto";
          } else if (distance > 1.5) {
            _feedback = "Acércate más al objeto";
          } else {
            _feedback = "¡Distancia perfecta! Puedes tomar la foto";
          }
        });
      }
    } catch (e) {
      print("Error en _updateDistanceFeedback: $e");
    }
  }

  void _addPlaneNode(ARKitPlaneAnchor anchor) {
    if (_arkitController == null) return;
    try {
      try {
        _arkitController!.removeAnchor(anchor.identifier);
      } catch (_) {}
      final material = ARKitMaterial(
        diffuse: ARKitMaterialProperty.color(
          Color.fromRGBO(30, 150, 255, 0.5),
        ),
        doubleSided: true,
      );
      final plane = ARKitPlane(
        width: anchor.extent.x,
        height: anchor.extent.z,
        materials: [material],
      );
      final planeNode = ARKitNode(
        geometry: plane,
        position: Vector3(anchor.center.x, 0, anchor.center.z),
        eulerAngles: Vector3(3.14 / 2, 0, 0),
      );
      _arkitController!.add(planeNode, parentNodeName: anchor.nodeName);
      print("Nodo de plano añadido para visualizar superficie detectada");
    } catch (e) {
      print("Error al añadir nodo de plano: $e");
    }
  }

 Future<void> _takePicture() async {
  if (_cameraController == null || !_cameraController!.value.isInitialized || _takingPicture) {
    return;
  }

  setState(() {
    _takingPicture = true;
    _showARKitOverlay = false;
  });

  try {
    await _cameraController!.stopImageStream(); // 👈 Detenemos el stream
    await Future.delayed(Duration(milliseconds: 300)); // 👈 Pequeña espera para asegurar el frame se actualice

    final XFile photo = await _cameraController!.takePicture();

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String filePath = path.join(appDir.path, fileName);

    final File savedImage = File(photo.path);
    final File newFile = await savedImage.copy(filePath);

    setState(() {
      _capturedImage = newFile;
    });
  } catch (e) {
    print("Error al tomar la foto: $e");
    setState(() {
      _feedback = "Error taking picture: $e";
    });
  } finally {
    _takingPicture = false;
  }
}


  Future<String?> _uploadImage() async {
    if (_capturedImage == null) {
      setState(() {
        _feedback = "No image to upload";
      });
      return null;
    }
    try {
      setState(() {
        _isLoading = true;
      });
      final downloadUrl =
          await _storageService.uploadProductImage(_capturedImage!);
      setState(() {
        _isLoading = false;
      });
      return downloadUrl;
    } catch (e) {
      setState(() {
        _isLoading = false;
        _feedback = "Error uploading image: $e";
      });
      return null;
    }
  }

  void _resetImage() {
    setState(() {
      _capturedImage = null;
      // Reactivar overlay para volver a la vista en vivo
      _showARKitOverlay = true;
    });
  }

  Color _getDistanceColor(double? distance) {
    if (distance == null) return CupertinoColors.systemGrey;
    if (distance < 0.3) return CupertinoColors.systemRed;
    if (distance > 1.5) return CupertinoColors.systemOrange;
    return CupertinoColors.activeGreen;
  }

  Color _getLightLevelColor(double lightLevel) {
    if (lightLevel < 0.2) return CupertinoColors.systemRed;
    if (lightLevel > 0.8) return CupertinoColors.systemOrange;
    return CupertinoColors.activeGreen;
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
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _capturedImage != null
                ? _buildImagePreview()
                : _buildCameraView(),
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_isInitialized || _cameraController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Camera not available"),
            const SizedBox(height: 20),
            CupertinoButton(
              child: const Text("Try Again"),
              onPressed: _initializeCamera,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),
        // Solo mostrar el overlay de ARKit si está activo y si la foto no fue capturada
        if (_hasLiDAR && _arKitView != null && _showARKitOverlay)
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: _arKitView!,
            ),
          ),
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _getDistanceColor(_distanceToObject),
                  width: 2.0,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _getDistanceColor(_distanceToObject),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Column(
            children: [
              if (_distanceToObject != null)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        _getDistanceColor(_distanceToObject).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: CupertinoColors.white,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _distanceToObject! < 0.3
                            ? CupertinoIcons.arrow_left
                            : _distanceToObject! > 1.5
                                ? CupertinoIcons.arrow_right
                                : CupertinoIcons.checkmark_circle,
                        color: CupertinoColors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Distancia: ${_distanceToObject!.toStringAsFixed(2)}m',
                        style: GoogleFonts.inter(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getLightLevelColor(_lightLevel).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Light: ${(_lightLevel * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _hasLiDAR
                      ? "LiDAR activo: Midiendo distancia..."
                      : "LiDAR no disponible",
                  style: GoogleFonts.inter(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_feedback.isNotEmpty)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _feedback.contains("erfecta") ||
                            _feedback.contains("Good")
                        ? CupertinoColors.activeGreen.withOpacity(0.7)
                        : _feedback.contains("Error")
                            ? CupertinoColors.destructiveRed.withOpacity(0.7)
                            : CupertinoColors.activeOrange.withOpacity(0.7),
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
                    children: [
                      Icon(
                        _feedback.contains("erfecta") ||
                                _feedback.contains("Good")
                            ? CupertinoIcons.camera_viewfinder
                            : _feedback.contains("Error")
                                ? CupertinoIcons.exclamationmark_triangle
                                : CupertinoIcons.info_circle,
                        color: CupertinoColors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _feedback,
                        style: GoogleFonts.inter(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
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
          bottom: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: _takingPicture ? null : _takePicture,
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
                  child: _takingPicture
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
              GestureDetector(
                onTap: () {
                  setState(() {
                    _distanceToObject = null;
                    _feedback = "Apunta a una superficie plana cercana";
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: CupertinoColors.darkBackgroundGray,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CupertinoColors.white,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.refresh,
                    color: CupertinoColors.white,
                    size: 25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: CupertinoColors.black,
            width: double.infinity,
            child: _capturedImage != null
                ? Image.file(
                    _capturedImage!,
                    fit: BoxFit.contain,
                  )
                : const Center(child: Text("No image captured")),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: CupertinoColors.darkBackgroundGray,
                child: Text(
                  "Retake",
                  style: GoogleFonts.inter(color: CupertinoColors.white),
                ),
                onPressed: _resetImage,
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: AppColors.primaryBlue,
                child: Text(
                  "Use Photo",
                  style: GoogleFonts.inter(color: CupertinoColors.white),
                ),
                onPressed: () async {
                  if (_capturedImage == null) return;
                  final downloadUrl = await _uploadImage();
                  widget.onImageCaptured(_capturedImage!, downloadUrl);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
