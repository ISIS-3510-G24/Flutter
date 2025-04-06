import 'dart:io';
import 'dart:async'; // Añadido para Timer
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

class _ProductCameraScreenState extends State<ProductCameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  ARKitController? _arkitController;
  FirebaseStorageService _storageService = FirebaseStorageService();
  
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _hasLiDAR = false;
  bool _takingPicture = false;
  bool _isProcessingImage = false;
  File? _capturedImage;
  Widget? _arKitView;
  
  // Sensor values
  double? _distanceToObject;
  double _lightLevel = 0.5; // Default middle value
  String _feedback = '';
  
  @override
  void initState() {
    super.initState();
    print("Iniciando ProductCameraScreen - comprobando ARKit y LiDAR");
    WidgetsBinding.instance.addObserver(this);
    
    // Comprobar estado de ARKit periódicamente para depuración
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
    // Crear el widget ARKit solo una vez
    _arKitView ??= ARKitSceneView(
        onARKitViewCreated: _onARKitViewCreated,
        configuration: ARKitConfiguration.worldTracking,
        planeDetection: ARPlaneDetection.horizontal,
      );
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Detener procesamiento de imágenes antes de liberar la cámara
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
    
    // Liberar ARKit con manejo de errores
    try {
      if (_arkitController != null) {
        _arkitController!.dispose();
      }
    } catch (e) {
      print("Error al liberar ARKitController: $e");
    }
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed, handle camera resources
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }
  
  Future<void> _initializeCamera() async {
    _isLoading = true;
    if (mounted) setState(() {});
    
    try {
      // Check for LiDAR support
      _hasLiDAR = await _checkLiDARSupport();
      print("LiDAR detectado: $_hasLiDAR");
      
      // Inicializar ARKit si hay LiDAR disponible
      if (_hasLiDAR) {
        _initializeARKit();
      }
      
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _feedback = "No cameras found";
        _isLoading = false;
        if (mounted) setState(() {});
        return;
      }
      
      // Use the back camera
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      
      // Initialize camera controller with high quality for better image
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high, // Volver a high para mejor calidad
        enableAudio: false,
        imageFormatGroup: Platform.isIOS 
            ? ImageFormatGroup.bgra8888 
            : ImageFormatGroup.yuv420,
      );
      
      await _cameraController!.initialize();
      
      // Start image stream for light detection if camera is initialized
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
  
  // Check if device supports LiDAR
  Future<bool> _checkLiDARSupport() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      
      // Imprime todos los detalles del dispositivo para depuración
      print("Modelo de dispositivo: ${iosInfo.model}");
      print("Todos los detalles del dispositivo: ${iosInfo.toString()}");
      
      // LiDAR is available on iPhone 12 Pro and later Pro models
      final String model = iosInfo.modelName;
      
      final bool hasLiDAR = model.contains('iPhone 12 Pro') ||
                          model.contains('iPhone 13 Pro') ||
                          model.contains('iPhone 14 Pro') ||
                          model.contains('iPhone 15 Pro') ||
                          (model.contains('iPad Pro') && 
                          int.parse(model.split(' ').last) >= 2020);
      
      print("¿Dispositivo compatible con LiDAR según modelo? $hasLiDAR");
      print("Modelo detectado: $model");
      
      return hasLiDAR;
    } catch (e) {
      print("Error detallado al verificar soporte LiDAR: $e");
      return false;
    }
  }
  
  // Process camera images to detect light levels
  void _processCameraImage(CameraImage image) {
    if (image.planes.isEmpty || _isProcessingImage || !mounted) return;
    
    _isProcessingImage = true;
    
    try {
      // Calculate average brightness from the Y plane (luminance)
      final plane = image.planes[0];
      int totalLuminance = 0;
      
      // Sample every 10th pixel for performance
      for (int i = 0; i < plane.bytes.length; i += 10) {
        totalLuminance += plane.bytes[i];
      }
      
      // Average brightness level (0-255)
      final int pixelCount = plane.bytes.length ~/ 10;
      final double averageLuminance = totalLuminance / pixelCount;
      
      // Normalize to 0-1 range
      final double normalizedLightLevel = averageLuminance / 255.0;
      
      // Update state with light level
      if (mounted) {
        setState(() {
          _lightLevel = normalizedLightLevel;
          
          // Only set feedback about light if we don't have distance feedback
          if (_distanceToObject == null) {
            if (normalizedLightLevel < 0.2) {
              _feedback = "Too dark, add more light";
            } else if (normalizedLightLevel > 0.8) {
              _feedback = "Too bright, reduce light";
            } else {
              _feedback = "Good lighting";
            }
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
    print("ARKit controller creado en iPhone - esperando detección de planos");
    print("_hasLiDAR: $_hasLiDAR");
    _arkitController = controller;
    
    // Añadir indicador de inicialización
    if (mounted) {
      setState(() {
        _feedback = "Mueve la cámara para detectar superficies";
      });
    }
    
    // Verificar que el controlador esté funcionando correctamente
    print("ARKit controller inicializado correctamente");
    
    // Establecer un temporizador para actualizar el feedback si no se detecta nada
    Future.delayed(Duration(seconds: 5), () {
      if (_distanceToObject == null && mounted) {
        setState(() {
          _feedback = "Apunta a una superficie plana cercana";
        });
      }
    });
    
    // Configuración para enfocarse en objetos cercanos
    try {
      // No añadimos ningún nodo de prueba para mantener la visualización limpia
      print("ARKit configurado para detección de planos cercanos");
    } catch (e) {
      print("Error en configuración inicial de ARKit: $e");
    }
    
    // Configuración para detección de planos con manejo de errores
    try {
      controller.onAddNodeForAnchor = (ARKitAnchor anchor) {
        print("ARKit: Se detectó una ancla de tipo: ${anchor.runtimeType}");
        if (anchor is ARKitPlaneAnchor) {
          try {
            _updateDistanceFeedback(anchor);
            
            if (mounted) {
              setState(() {
                _feedback = "Superficie detectada a ${_distanceToObject?.toStringAsFixed(2)}m";
              });
            }
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
  
  // Update distance feedback from LiDAR
  void _updateDistanceFeedback(ARKitPlaneAnchor anchor) {
    try {
      // Distance in meters (safe access)
      final Vector4 column = anchor.transform.getColumn(3);
      final double distance = column.z;
      
      // Solo procesar planos cercanos (menos de 2 metros)
      if (distance > 2.0) {
        return; // Ignorar planos lejanos
      }
      
      // Solo actualizar si el nuevo valor es mejor (más cercano al rango ideal)
      bool shouldUpdate = false;
      
      if (_distanceToObject == null) {
        shouldUpdate = true;
      } else if (_distanceToObject! < 0.3 && distance >= 0.3 && distance <= 1.5) {
        // Si estábamos muy cerca y ahora estamos en buen rango
        shouldUpdate = true;
      } else if (_distanceToObject! > 1.5 && distance >= 0.3 && distance <= 1.5) {
        // Si estábamos muy lejos y ahora estamos en buen rango
        shouldUpdate = true;
      } else if (distance >= 0.3 && distance <= 1.5) {
        // Si el nuevo valor está en el rango bueno
        shouldUpdate = true;
      }
      
      if (shouldUpdate && mounted) {
        setState(() {
          _distanceToObject = distance;
          
          // Provide feedback based on distance
          if (distance < 0.3) {
            _feedback = "Demasiado cerca del objeto";
          } else if (distance > 1.5) {
            _feedback = "Acércate más al objeto";
          } else {
            _feedback = "¡Buena distancia! Puedes tomar la foto";
          }
        });
        
        // Resaltar el plano detectado con un nodo visual
        _addPlaneNode(anchor);
      }
    } catch (e) {
      print("Error en _updateDistanceFeedback: $e");
    }
  }
  
  // Añadir un nodo visual para mostrar el plano detectado
  void _addPlaneNode(ARKitPlaneAnchor anchor) {
    if (_arkitController == null) return;
    
    try {
      // Eliminar nodos antiguos para evitar sobrecarga
      _arkitController!.removeAnchor(anchor.identifier);
      
      // Añadir una geometría plana para visualizar la superficie detectada
      final material = ARKitMaterial(
        diffuse: ARKitMaterialProperty.color(
          Color.fromRGBO(30, 150, 255, 0.5), // Azul semitransparente
        ),
      );
      
      // Crear geometría del plano
      final plane = ARKitPlane(
        width: anchor.extent.x,
        height: anchor.extent.z,
        materials: [material],
      );
      
      // Crear nodo en la posición del ancla
      final planeNode = ARKitNode(
        geometry: plane,
        position: Vector3(anchor.center.x, 0, anchor.center.z),
        eulerAngles: Vector3(3.14 / 2, 0, 0), // Rotación para hacer horizontal
      );
      
      // Añadir nodo al controlador con el ID del ancla
      _arkitController!.add(planeNode, parentNodeName: anchor.nodeName);
      
      print("Nodo de plano añadido para visualizar superficie detectada");
    } catch (e) {
      print("Error al añadir nodo de plano: $e");
    }
  }
  
  // Take a picture
  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    if (_takingPicture) {
      return;
    }
    
    try {
      setState(() {
        _takingPicture = true;
      });
      
      final XFile photo = await _cameraController!.takePicture();
      
      // Create a more descriptive file path
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(appDir.path, fileName);
      
      // Copy the file to the new path
      final File savedImage = File(photo.path);
      final File newFile = await savedImage.copy(filePath);
      
      setState(() {
        _capturedImage = newFile;
        _takingPicture = false;
      });
    } catch (e) {
      setState(() {
        _takingPicture = false;
        _feedback = "Error taking picture: $e";
      });
    }
  }
  
  // Upload image to Firebase Storage
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
      
      // Upload to Firebase Storage
      final downloadUrl = await _storageService.uploadProductImage(_capturedImage!);
      
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
  
  // Reset captured image
  void _resetImage() {
    setState(() {
      _capturedImage = null;
    });
  }
  
  // Get color based on distance
  Color _getDistanceColor(double? distance) {
    if (distance == null) return CupertinoColors.systemGrey;
    if (distance < 0.3) return CupertinoColors.systemRed;
    if (distance > 1.5) return CupertinoColors.systemOrange;
    return CupertinoColors.activeGreen;
  }
  
  // Get color based on light level
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
        // Camera preview
        Positioned.fill(
          child: AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),
        
        // ARKit view - ponemos esto DEBAJO de la cámara en el stack para que la cámara sea visible
        if (_hasLiDAR && _arKitView != null)
          Positioned.fill(
            child: Stack(
              children: [
                // ARKit view transparente excepto para los elementos de depuración
                Positioned.fill(
                  child: _arKitView!,
                ),
                // Botón de debug para probar la funcionalidad de ARKit
                Positioned(
                  bottom: 90,
                  right: 20,
                  child: GestureDetector(
                    onTap: () {
                      _simularDeteccionPlano();
                    },
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBlue.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        CupertinoIcons.wand_stars,
                        color: CupertinoColors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
        // Sensor feedback badges
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // LiDAR distance badge
                              if (_distanceToObject != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getDistanceColor(_distanceToObject).withOpacity(0.7),
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
                
              // Light level badge
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              
              // LiDAR status badge
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _hasLiDAR ? "LiDAR disponible: Buscando superficies..." : "LiDAR no disponible",
                  style: GoogleFonts.inter(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Feedback message
              if (_feedback.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _feedback.contains("Buena") || _feedback.contains("Good")
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
                        _feedback.contains("Buena") || _feedback.contains("Good")
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
        
        // Camera controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Capture button
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
            ],
          ),
        ),
      ],
    );
  }
  
    // Método para simular una detección de plano cuando el usuario presiona el botón de debug
  void _simularDeteccionPlano() {
    print("Simulando detección de plano para propósitos de debug");
    
    // Crear valores simulados para probar la funcionalidad
    final simulatedDistance = 1.0; // Distancia ideal
    
    if (mounted) {
      setState(() {
        _distanceToObject = simulatedDistance;
        _feedback = "¡Distancia perfecta! Puedes tomar la foto";
      });
    }
    
    // Crear un nodo visual para representar un plano simulado
    if (_arkitController != null) {
      try {
        // Crear un nodo de plano simulado
        final material = ARKitMaterial(
          diffuse: ARKitMaterialProperty.color(
            CupertinoColors.activeBlue.withOpacity(0.5),
          ),
          doubleSided: true
        );
        
        final plane = ARKitPlane(
          width: 1.0,
          height: 1.0,
          materials: [material]
        );
        
        // Nodo para el plano simulado
        final planeNode = ARKitNode(
          name: "simulated_plane",
          geometry: plane,
          position: Vector3(0, -0.5, -1.0),
          eulerAngles: Vector3(3.14/2, 0, 0)
        );
        
        // Intentar eliminar el nodo si ya existe
        try {
          _arkitController!.remove("simulated_plane");
        } catch (e) {
          // No hacer nada si el nodo no existía
        }
        
        _arkitController!.add(planeNode);
        print("Plano simulado añadido para debug");
      } catch (e) {
        print("Error al añadir plano simulado: $e");
      }
    }
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        // Image preview
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
        
        // Buttons
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Retake button
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: CupertinoColors.darkBackgroundGray,
                child: Text(
                  "Retake",
                  style: GoogleFonts.inter(color: CupertinoColors.white),
                ),
                onPressed: _resetImage,
              ),
              
              // Use photo button
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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