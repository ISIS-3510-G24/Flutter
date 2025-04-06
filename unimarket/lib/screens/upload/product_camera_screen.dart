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
  CameraController? _cameraController;
  ARKitController? _arkitController;
  FirebaseStorageService _storageService = FirebaseStorageService();
  final LightSensorService _lightSensorService = LightSensorService();
  
  bool _isInitialized = false;
  bool _measurementMode = false; // Para controlar qué modo está activo
  bool _isLoading = true;
  bool _hasLiDAR = false;
  bool _takingPicture = false;
  bool _isProcessingImage = false;
  bool _showARKitOverlay = true;
  File? _capturedImage;
  Widget? _arKitView;

  // Variables para sensores y control
  String _feedback = '';
  DateTime? _lastLightUpdate;

  // Variables para medición
  Vector3? _lastPosition;
  List<ARKitNode> _measurementNodes = [];
  String _currentMeasurement = '';

 @override
void initState() {
  super.initState();
  print("📸 Iniciando ProductCameraScreen");
  WidgetsBinding.instance.addObserver(this);
  
  // Asegurar inicialización limpia
  _feedback = '';
  _lastPosition = null;
  _currentMeasurement = '';
  _measurementNodes = [];
  _measurementMode = false; // Iniciar en modo luz
  
  // Iniciar cámara
  Future.microtask(() => _initializeCamera());
}


  void _initializeARKit() {
    _arKitView ??= ARKitSceneView(
      onARKitViewCreated: _onARKitViewCreated,
      configuration: ARKitConfiguration.worldTracking,
      enableTapRecognizer: true,
      planeDetection: ARPlaneDetection.horizontal,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

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
    
    // Liberar sensor de luz
    _lightSensorService.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
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
    print("🔍 LiDAR detectado: $_hasLiDAR");

    // No inicializar ARKit automáticamente, solo verificar si está disponible
    // El ARKit se inicializará cuando el usuario cambie al modo de medición

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() {
        _isLoading = false;
        _feedback = "No se encontraron cámaras";
      });
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

    // Inicializar cámara y asegurar que sea exitoso
    await _cameraController!.initialize();
    
    // Pequeña pausa para asegurar inicialización completa
    await Future.delayed(Duration(milliseconds: 300));
    
    if (_cameraController!.value.isInitialized) {
      // Iniciar modo luz por defecto
      if (!_measurementMode) {
        await _startLightMode();
      }
    }

    _isInitialized = true;
    _isLoading = false;
    if (mounted) setState(() {});
  } catch (e) {
    print("❌ Error completo al inicializar la cámara: $e");
    _feedback = "Error initializing camera: $e";
    _isLoading = false;
    if (mounted) setState(() {});
  }
}

Future<void> _startLightMode() async {
  if (_cameraController == null || !_cameraController!.value.isInitialized) {
    setState(() {
      _feedback = "Cámara no inicializada";
      _isLoading = false;
    });
    return;
  }
  
  try {
    // Asegurar que ARKit está desactivado
    setState(() {
      _showARKitOverlay = false;
    });
    
    // Garantizar que el stream está detenido antes de iniciar uno nuevo
    if (_cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
      await Future.delayed(Duration(milliseconds: 200));
    }
    
    // Iniciar nuevo stream con manejo de errores mejorado
    try {
      await _cameraController!.startImageStream(_processCameraImage);
      print("✅ Stream de cámara para luz iniciado correctamente");
      setState(() {
        _feedback = "Modo sensor de luz activado";
      });
    } catch (e) {
      print("⚠️ Error al iniciar stream de cámara: $e");
      setState(() {
        _feedback = "Error con el sensor de luz";
      });
      
      // Intento de recuperación
      await Future.delayed(Duration(milliseconds: 500));
      try {
        if (!_cameraController!.value.isStreamingImages) {
          await _cameraController!.startImageStream(_processCameraImage);
          setState(() {
            _feedback = "Modo luz recuperado";
          });
        }
      } catch (retryError) {
        print("⚠️ Error al reintentar stream: $retryError");
      }
    }
  } catch (e) {
    print("Error general en _startLightMode: $e");
    setState(() {
      _feedback = "Error en modo luz";
    });
  }
}

// Método para cambiar al modo medición
Future<void> _startMeasurementMode() async {
  if (!_hasLiDAR) {
    setState(() {
      _feedback = "LiDAR no disponible en este dispositivo";
    });
    return;
  }
  
  // Detener el stream de cámara para ahorrar recursos
  if (_cameraController != null && _cameraController!.value.isStreamingImages) {
    await _cameraController!.stopImageStream();
  }
  
  // Inicializar ARKit si no está inicializado
  if (_arkitController == null) {
    _initializeARKit();
  }
  
  setState(() {
    _feedback = "Modo medición activado. Toca para medir";
    _showARKitOverlay = true;
  });
}

Future<void> _toggleMode() async {
  if (_isLoading) return;
  
  setState(() {
    _isLoading = true;
    _feedback = _measurementMode 
        ? "Cambiando a modo luz..." 
        : "Cambiando a modo medición...";
  });
  
  try {
    // Hacer una pausa para liberar recursos
    await Future.delayed(Duration(milliseconds: 200));
    
    // Cambiar el modo
    _measurementMode = !_measurementMode;
    
    // Asegurar que ARKit y la cámara se liberan adecuadamente
    if (_measurementMode) {
      // Cambiar a modo medición
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
          await Future.delayed(Duration(milliseconds: 200));
        } catch (e) {
          print("Error al detener stream en cambio de modo: $e");
        }
      }
      await _startMeasurementMode();
    } else {
      // Cambiar a modo luz
      if (_arkitController != null) {
        for (final node in _measurementNodes) {
          try {
            _arkitController?.remove(node.name);
          } catch (e) {
            print("Error al eliminar nodo ARKit: $e");
          }
        }
        _measurementNodes.clear();
        _lastPosition = null;
        _currentMeasurement = '';
      }
      await Future.delayed(Duration(milliseconds: 300));
      await _startLightMode();
    }
  } catch (e) {
    print("❌ Error en _toggleMode: $e");
    setState(() {
      _feedback = "Error al cambiar modo: ${e.toString().substring(0, 50)}";
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
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
      print("❌ Error detallado al verificar soporte LiDAR: $e");
      return false;
    }
  }

  void _processCameraImage(CameraImage image) {
  // Throttling para reducir procesamiento
  final now = DateTime.now();
  if (_lastLightUpdate != null && 
      now.difference(_lastLightUpdate!).inMilliseconds < 500) {
    return;
  }
  _lastLightUpdate = now;
  
  // Usar el servicio de luz para procesar la imagen
  _lightSensorService.processCameraImage(image);
  
  // Actualizar UI con los resultados del sensor de manera explícita
  if (mounted) {
    setState(() {
      // Obtener valor actual del notificador
      final lightFeedback = _lightSensorService.feedbackNotifier.value;
      _feedback = lightFeedback;
      
      // Imprimir para diagnóstico
      print("📊 UI Feedback actualizado: $_feedback");
    });
  }
}

  void _onARKitViewCreated(ARKitController controller) {
    print("🔍 ARKit controller creado");
    _arkitController = controller;

    if (mounted) {
      setState(() {
        _feedback = "Toca para empezar a medir";
      });
    }

    // Configurar el detector de toques
    controller.onARTap = (List<ARKitTestResult> ar) {
      final ARKitTestResult? point = ar.firstWhereOrNull(
        (o) => o.type == ARKitHitTestResultType.featurePoint,
      );
      
      if (point != null) {
        _onARTapHandler(point);
      }
    };
  }

  void _onARTapHandler(ARKitTestResult point) {
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
    );
    
    _arkitController?.add(node);
    _measurementNodes.add(node);

    // Si ya tenemos un punto anterior, dibujar una línea entre los puntos
    if (_lastPosition != null) {
      final line = ARKitLine(
        fromVector: _lastPosition!,
        toVector: position,
      );
      
      final lineNode = ARKitNode(geometry: line);
      _arkitController?.add(lineNode);
      _measurementNodes.add(lineNode);

      // Calcular y mostrar la distancia
      final distance = _calculateDistanceBetweenPoints(position, _lastPosition!);
      final midPoint = _getMiddleVector(position, _lastPosition!);
      _drawText(distance, midPoint);
      
      setState(() {
        _currentMeasurement = distance;
      });
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
    );
    
    _arkitController?.add(node);
    _measurementNodes.add(node);
  }

  void _clearMeasurements() {
    _lastPosition = null;
    
    for (final node in _measurementNodes) {
      _arkitController?.remove(node.name);
    }
    
    _measurementNodes.clear();
    
    setState(() {
      _currentMeasurement = '';
      _feedback = "Toca para empezar a medir";
    });
  }

 Future<void> _takePicture() async {
  if (_cameraController == null || !_cameraController!.value.isInitialized || _takingPicture) {
    return;
  }

  setState(() {
    _takingPicture = true;
    _feedback = "Capturando imagen...";
  });

  // Valores para guardar el estado actual y restaurarlo después
  final bool wasMeasurementMode = _measurementMode;
  final bool wasARKitVisible = _showARKitOverlay;

  try {
    // 1. Bloquear temporalmente tanto ARKit como el análisis de luz
    setState(() {
      _showARKitOverlay = false;
    });
    
    // 2. Esperar a que la UI se actualice
    await Future.delayed(Duration(milliseconds: 100));
    
    // 3. Método especial para liberar recursos de modo seguro antes de capturar
    await _safelyPrepareForCapture();
    
    // 4. Tomar la foto
    print("📸 Tomando foto...");
    final XFile? photo = await _tryTakePictureWithRetry();
    if (photo == null) {
      throw Exception("No se pudo capturar la imagen después de varios intentos");
    }
    print("✅ Foto tomada correctamente");

    // 5. Procesar la imagen
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String filePath = path.join(appDir.path, fileName);

    print("💾 Guardando imagen en $filePath");
    final File savedImage = File(photo.path);
    final File newFile = await savedImage.copy(filePath);
    print("✅ Imagen guardada");

    // 6. Actualizar UI con la imagen capturada
    if (mounted) {
      setState(() {
        _capturedImage = newFile;
      });
    }
  } catch (e) {
    print("❌ Error detallado al tomar la foto: $e");
    print("Stack trace: ${StackTrace.current}");
    
    if (mounted) {
      setState(() {
        // Manejo seguro del mensaje de error para evitar errores de rango
        String errorMessage = e.toString();
        _feedback = "Error: " + (errorMessage.length > 40 ? 
            errorMessage.substring(0, 40) + "..." : errorMessage);
      });
      
      // Restaurar modo anterior tras el error
      _safelyRestorePreviousMode(wasMeasurementMode, wasARKitVisible);
    }
  } finally {
    if (mounted) {
      setState(() {
        _takingPicture = false;
      });
    }
  }
}

// El método _uploadImage debe estar al mismo nivel que _takePicture, no anidado dentro de él:
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

// Nuevo método para intentar tomar una foto con reintentos
Future<XFile?> _tryTakePictureWithRetry() async {
  XFile? photo;
  int attempts = 0;
  const maxAttempts = 3;

  while (attempts < maxAttempts && photo == null) {
    try {
      attempts++;
      print("📸 Intento $attempts de tomar foto");
      
      // Si no es el primer intento, esperar un poco más
      if (attempts > 1) {
        await Future.delayed(Duration(milliseconds: 800));
      }
      
      photo = await _cameraController!.takePicture();
      return photo;
    } catch (e) {
      print("⚠️ Error en intento $attempts: $e");
      
      // Si es el error específico de iOS "Cannot Record", intentar reiniciar la cámara
      if (e.toString().contains("Cannot Record") && attempts < maxAttempts) {
        print("🔄 Intentando recuperar la cámara...");
        try {
          // Liberar y reiniciar la cámara entre intentos
          await _quickCameraReset();
        } catch (resetError) {
          print("⚠️ Error al reiniciar: $resetError");
        }
      }
    }
  }
  
  return null; // No se pudo tomar la foto después de varios intentos
}

// Nuevo método para preparar la cámara de manera segura antes de capturar
Future<void> _safelyPrepareForCapture() async {
  try {
    // Detener todos los procesos que puedan interferir con la captura
    if (_arkitController != null) {
      // No intentar eliminar nodos, solo ocultar ARKit
      print("🔍 Pausando ARKit para captura");
    }
    
    // Detener cualquier stream de cámara activo
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
        print("📷 Stream de cámara detenido para foto");
      } catch (e) {
        print("⚠️ Advertencia al detener stream: $e");
        // Continuar incluso si hay error
      }
    }
    
    // Pausa para asegurar que los recursos están liberados
    await Future.delayed(Duration(milliseconds: 500));
    
  } catch (e) {
    print("⚠️ Error preparando cámara: $e");
    // No relanzar error, intentar tomar la foto de todos modos
  }
}

 // 4. Mejora al método de reinicio de imagen para mayor robustez
void _resetImage() {
  if (_isLoading) return;
  
  setState(() {
    _capturedImage = null;
    _isLoading = true;
    _feedback = "Reiniciando cámara...";
  });

  
  // Usar un enfoque más seguro para la reinicialización
  Future.microtask(() async {
    try {
      // 1. Detener todos los procesos activos
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          try {
            await _cameraController!.stopImageStream();
            await Future.delayed(Duration(milliseconds: 100));
          } catch (e) {
            print("Error al detener stream: $e");
          }
        }
        
        try {
          await _cameraController!.dispose();
        } catch (e) {
          print("Error al liberar cámara: $e");
        }
        _cameraController = null;
      }
      
      if (_arkitController != null) {
        try {
          _arkitController!.dispose();
        } catch (e) {
          print("Error al liberar ARKit: $e");
        }
        _arkitController = null;
        _arKitView = null;
      }
      
      // 2. Limpiar estado
      _measurementNodes.clear();
      _lastPosition = null;
      _currentMeasurement = '';
      
      // 3. Esperar antes de reiniciar
      await Future.delayed(Duration(milliseconds: 500));
      
      // 4. Reiniciar cámara desde cero
      await _initializeCamera();
      
      // 5. Restaurar el modo previo
      if (mounted) {
        setState(() {
          if (_measurementMode) {
            _showARKitOverlay = true;
            Future.microtask(() => _startMeasurementMode());
          } else {
            _showARKitOverlay = false;
          }
        });
      }
    } catch (e) {
      print("Error durante reinicio: $e");
      if (mounted) {
        setState(() {
          _feedback = "Error al reiniciar. Intenta de nuevo.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  });
}

// Método para un reinicio rápido de la cámara
Future<void> _quickCameraReset() async {
  try {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    
    // Liberar cámara actual
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    
    // Pequeña pausa
    await Future.delayed(Duration(milliseconds: 300));
    
    // Crear nueva instancia de cámara
    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    
    // Inicializar (sin iniciar streaming)
    await _cameraController!.initialize();
    await Future.delayed(Duration(milliseconds: 200));
    
  } catch (e) {
    print("❌ Error en reinicio rápido de cámara: $e");
    // Permitir que el error se propague
    throw e;
  }
}

Future<void> _safelyRestorePreviousMode(bool wasMeasurementMode, bool wasARKitVisible) async {
  try {
    if (wasMeasurementMode) {
      // Esperar un poco para evitar conflictos
      await Future.delayed(Duration(milliseconds: 300));
      setState(() { 
        _showARKitOverlay = wasARKitVisible;
        _measurementMode = true;
        _feedback = "Modo medición restaurado";
      });
    } else {
      // Restaurar modo luz
      setState(() { 
        _showARKitOverlay = false;
        _measurementMode = false; 
      });
      
      // Intentar reiniciar el stream de luz después de un momento
      Future.delayed(Duration(milliseconds: 500), () async {
        try {
          if (_cameraController != null && 
              _cameraController!.value.isInitialized && 
              !_cameraController!.value.isStreamingImages) {
            await _cameraController!.startImageStream(_processCameraImage);
            if (mounted) setState(() { 
              _feedback = "Modo luz restaurado";
            });
          }
        } catch (e) {
          print("Error al restaurar stream de luz: $e");
          if (mounted) setState(() {
            _feedback = "Error al restaurar modo luz";
          });
        }
      });
    }
  } catch (e) {
    print("Error al restaurar modo: $e");
  }
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

  // Obtener valores del sensor de luz
  final lightLevel = _lightSensorService.lightLevelNotifier.value;
  final lightColor = _lightSensorService.getLightLevelColor(lightLevel);
  final lightFeedback = _lightSensorService.feedbackNotifier.value;

  return Stack(
    children: [
      // Vista de la cámara
      Positioned.fill(
        child: AspectRatio(
          aspectRatio: _cameraController!.value.aspectRatio,
          child: CameraPreview(_cameraController!),
        ),
      ),
      
      // Vista de ARKit para medición (solo visible en modo medición)
      if (_hasLiDAR && _arKitView != null && _showARKitOverlay && _measurementMode)
        Positioned.fill(
          child: _arKitView!,
        ),
      
      // Indicadores superiores
      Positioned(
        top: 16,
        left: 0,
        right: 0,
        child: Column(
          children: [
            // Indicador de modo actual
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
            
            // Estado de LiDAR (solo visible si está disponible)
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
            
            // Feedback y mediciones
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
                  children: [
                    Icon(
                      _measurementMode && _currentMeasurement.isNotEmpty
                          ? CupertinoIcons.scope
                          : CupertinoIcons.info_circle,
                      color: CupertinoColors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
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
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      
      // Botones inferiores
      Positioned(
        left: 0,
        right: 0,
        bottom: 32,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Botón de cambio de modo (Nuevo)
            GestureDetector(
              onTap: _isLoading ? null : _toggleMode,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _measurementMode 
                      ? CupertinoColors.activeBlue
                      : lightColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.white,
                    width: 2,
                  ),
                ),
                child: Icon(
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
            
            // Botón de limpiar mediciones (solo visible en modo medición)
            _measurementMode
                ? GestureDetector(
                    onTap: _clearMeasurements,
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
                  )
                : SizedBox(width: 50), // Espacio vacío para mantener la distribución
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: CupertinoColors.darkBackgroundGray,
                child: Text(
                  "Retake",
                  style: GoogleFonts.inter(color: CupertinoColors.white),
                ),
                onPressed: _resetImage,
              ),
              CupertinoButton(
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  color: AppColors.primaryBlue,
  child: Text(
    "Use Photo",
    style: GoogleFonts.inter(color: CupertinoColors.white),
  ),
  onPressed: () async {
    if (_capturedImage == null) return;
    
    setState(() {
      _isLoading = true; // Show loading indicator
    });
    
    final downloadUrl = await _uploadImage();
    
    // Call the callback and ensure navigation happens
    widget.onImageCaptured(_capturedImage!, downloadUrl);
    
    // Explicitly pop with a slight delay to ensure the callback completes
    await Future.delayed(Duration(milliseconds: 100));
    if (mounted) Navigator.of(context).pop();
  },
),
            ],
          ),
        ),
      ],
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
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _capturedImage != null
              ? _buildImagePreview()  // Aquí está el problema, no tiene guion bajo
              : _buildCameraView(),
    ),
  );
}
}