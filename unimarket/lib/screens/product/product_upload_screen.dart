import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/measurement_model.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/screens/product/queued_products_screen.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/upload/product_camera_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class UploadProductScreen extends StatefulWidget {
  const UploadProductScreen({super.key});

  @override
  UploadProductScreenState createState() => UploadProductScreenState();
}

class UploadProductScreenState extends State<UploadProductScreen> {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  String? _tempSelectedMajor;
  bool _isClassLoading = false;
  File? _productImage;
  String? _imageUrl;
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isOffline = false;
  final ProductService _productService = ProductService();
  MeasurementData? _measurementData;
  List<String> _measurementTexts = [];

  // Form fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedMajor = "No major";
  String _selectedClass = "No class";
  List<String> _labels = [];
  final List<String> _availableLabels = [
    "Academics","Education","Technology","Electronics","Art","Design","Engineering",
    "Handcrafts","Fashion","Accessories","Sports","Wellness","Entertainment","Home","Decoration","Other"
  ];
  bool _isLoading = false;
  bool _isUploading = false; // New flag to track upload state
  List<String> _availableMajors = ["No major"];
  List<Map<String, dynamic>> _availableClasses = [];
  List<String> _availableClassNames = ["No class"];

  // Added cancelable timer
  Timer? _uploadTimer;

  @override
  void initState() {
    super.initState();
    
    // First establish default state to avoid blocking
    _availableMajors = ["No major"];
    
    // Check connectivity immediately
    _checkConnectivityAndLoad();
    

      // IMPORTANT: Add this timer to ensure loading state exits even if offline
  Future.delayed(Duration(seconds: 3), () {
    if (mounted && _isLoading) {
      debugPrint('⚠️ Forced exit from loading state after timeout');
      setState(() {
        _isLoading = false;
      });
    }
  });
    // Set up listener for connectivity changes
    _connectivityService.connectivityStream.listen((hasInternet) {
      if (mounted) {
        setState(() {
          _isOffline = !hasInternet;
        });
      }
    });
    
    // Set up listeners for local draft
    _titleController.addListener(_saveDraftLocally);
    _descriptionController.addListener(_saveDraftLocally);
    _priceController.addListener(_saveDraftLocally);
  }

  // Improved connectivity check and initial load method
  Future<void> _checkConnectivityAndLoad() async {
    // Load draft data first (works offline)
    await _loadDraftIfAny();
    
    // Check connectivity
    final bool hasInternet = await _connectivityService.checkConnectivity();
    
    if (mounted) {
      setState(() {
        _isOffline = !hasInternet;
      });
      
      // Only fetch from Firebase if we have internet
      if (hasInternet) {
        _fetchAvailableMajors();
      }
    }
  }

  @override
  void dispose() {
    // Cancel any active timers to prevent memory leaks
    _uploadTimer?.cancel();
    
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    
    // Remove listeners to avoid calls to setState after dispose
    _titleController.removeListener(_saveDraftLocally);
    _descriptionController.removeListener(_saveDraftLocally);
    _priceController.removeListener(_saveDraftLocally);
    
    super.dispose();
  }

  // Helper to load any local draft from SharedPreferences
  Future<void> _loadDraftIfAny() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Attempt to read each piece of data
      final storedPath = prefs.getString('draft_image_path');
      final storedTitle = prefs.getString('draft_title') ?? '';
      final storedDesc = prefs.getString('draft_desc') ?? '';
      final storedPrice = prefs.getString('draft_price') ?? '';
      final storedMajor = prefs.getString('draft_major') ?? 'No major';
      final storedClass = prefs.getString('draft_class') ?? 'No class';
      final storedLabels = prefs.getStringList('draft_labels') ?? [];
      
      // If we have an image path, set our _productImage from that
      File? loadedImage;
      if (storedPath != null && storedPath.isNotEmpty) {
        final tempFile = File(storedPath);
        if (await tempFile.exists()) {
          loadedImage = tempFile;
        }
      }
      
      // Update state with loaded data
      if (mounted) {
        setState(() {
          if (loadedImage != null) {
            _productImage = loadedImage;
          }
          _titleController.text = storedTitle;
          _descriptionController.text = storedDesc;
          _priceController.text = storedPrice;
          _selectedMajor = storedMajor;
          _selectedClass = storedClass;
          _labels = storedLabels;
        });
      }
      
      // If major != "No major", re-fetch classes
      if (_selectedMajor != "No major") {
        await _fetchClassesForMajor(_selectedMajor);
      }
    } catch (e) {
      print("Error loading draft: $e");
      // Continue without draft data if there's an error
    }
  }

  // Helper to save (or update) a draft in SharedPreferences
  Future<void> _saveDraftLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store form fields
      await prefs.setString('draft_title', _titleController.text.trim());
      await prefs.setString('draft_desc', _descriptionController.text.trim());
      await prefs.setString('draft_price', _priceController.text.trim());
      await prefs.setString('draft_major', _selectedMajor);
      await prefs.setString('draft_class', _selectedClass);
      await prefs.setStringList('draft_labels', _labels);
      
      // Store image path if we have one
      if (_productImage != null) {
        await prefs.setString('draft_image_path', _productImage!.path);
      }
    } catch (e) {
      print("Error saving draft: $e");
      // Continue even if saving fails
    }
  }

  // Clear all draft data after successful upload
  Future<void> _clearDraft() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('draft_title');
  await prefs.remove('draft_desc');
  await prefs.remove('draft_price');
  await prefs.remove('draft_major');
  await prefs.remove('draft_class');
  await prefs.remove('draft_labels');
  await prefs.remove('draft_image_path');
}

  // Save image to the device's photo library (iOS camera roll)
  Future<void> _saveImageToGallery(File imageFile) async {
    try {
      final result = await ImageGallerySaver.saveFile(imageFile.path);
      if (result['isSuccess'] == true) {
        print("Image saved to gallery: ${result['filePath']}");
      } else {
        print("Failed to save image to gallery");
      }
    } catch (e) {
      print("Error saving image to gallery: $e");
    }
  }

  // Helper method to store the image file in the app's Documents directory
  Future<File> _saveImageLocally(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final localPath = p.join(directory.path, fileName);
    return imageFile.copy(localPath);
  }

  // Handle image capture from camera screen
  void _handleImageCaptured(File image, MeasurementData? measurementData) async {
    try {
      final localImage = await _saveImageLocally(image);
      
      if (mounted) {
        setState(() {
          _productImage = localImage;
          _imageUrl = null;
          _measurementData = measurementData;
          
          // Convert measurements to text
          _measurementTexts = [];
          if (measurementData != null && measurementData.lines.isNotEmpty) {
            for (var line in measurementData.lines) {
              _measurementTexts.add(line.measurement);
            }
            
            // If measurements exist, append them to the description
            if (_measurementTexts.isNotEmpty) {
              String currentDescription = _descriptionController.text;
              String measurementsText = "\n\nMeasurements:\n- " + _measurementTexts.join("\n- ");
              
              // Only add if not already there
              if (!currentDescription.contains("Measurements:")) {
                _descriptionController.text = currentDescription + measurementsText;
              }
            }
          }
        });
      }
      
      // Save draft whenever we get a new image
      _saveDraftLocally();
    } catch (e) {
      print("Error saving captured image: $e");
      _showErrorAlert('Error saving image: $e');
    }
  }

  void _navigateToCameraScreen() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ProductCameraScreen(
          onImageCaptured: (File image, MeasurementData? measurementData) {
            _handleImageCaptured(image, measurementData);
          },
        ),
      ),
    );
  }
Future<void> _fetchAvailableMajors() async {
  // Abortamos si el State ya no está montado
  if (!mounted) {
    debugPrint('🔍 _fetchAvailableMajors: widget ya desmontado, abortando');
    return;
  }

  debugPrint('🔍 _fetchAvailableMajors: iniciando, marcando isLoading=true');
  setState(() {
    _isLoading = true;
  });

  try {
    // 1) Chequeo de conectividad
    final bool hasInternet = await _connectivityService.checkConnectivity();
    debugPrint('🔌 _fetchAvailableMajors: conectividad = $hasInternet');

    if (!hasInternet) {
      debugPrint('⚠️ _fetchAvailableMajors: sin internet, usando default');
      if (!mounted) return;
      setState(() {
        _availableMajors = ['No major'];
        _isLoading = false;
      });
      return;
    }

    // 2) Llamada a Firestore con timeout
    debugPrint('📡 _fetchAvailableMajors: solicitando majors a Firestore');
    final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('majors')
        .get()
        .timeout(const Duration(seconds: 10));
    debugPrint('✅ _fetchAvailableMajors: recibidos ${querySnapshot.docs.length} majors');

    // 3) Procesar resultado
    final List<String> majors = ['No major']
      ..addAll(querySnapshot.docs.map((d) => d.id));
    debugPrint('📝 _fetchAvailableMajors: lista = $majors');

    if (!mounted) return;
    setState(() {
      _availableMajors = majors;
      _isLoading = false;
    });
    debugPrint('✔️ _fetchAvailableMajors: estado actualizado');
  } catch (e, st) {
    debugPrint('🚨 _fetchAvailableMajors error: $e\n$st');
    if (!mounted) return;
    setState(() {
      _availableMajors = ['No major'];
      _isLoading = false;
    });
    _showBriefToast('No se pudieron cargar carreras. Usando default.');
  }
}


  // Simple Cupertino-style toast or brief notification
  void _showBriefToast(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        content: Text(message),
      ),
    );

    // Automatically dismiss the dialog after 2 seconds
    Future.delayed(Duration(seconds: 2), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  // Fetch classes for the selected major
  Future<void> _fetchClassesForMajor(String majorId) async {
    if (majorId == "No major") {
      setState(() {
        _availableClasses = [];
        _availableClassNames = ["No class"];
        _selectedClass = "No class";
      });
      return;
    }
    
    if (mounted) {
      setState(() {
        _isClassLoading = true;
      });
    }
    
    try {
      List<Map<String, dynamic>> classes = 
          await _firebaseDAO.getClassesForMajor(majorId);
      
      List<String> classNames = ["No class"];
      for (var classItem in classes) {
        classNames.add(classItem['name'] ?? classItem['id']);
      }
      
      if (mounted) {
        setState(() {
          _availableClasses = classes;
          _availableClassNames = classNames;
          _selectedClass = "No class";
          _isClassLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableClasses = [];
          _availableClassNames = ["No class"];
          _selectedClass = "No class";
          _isClassLoading = false;
        });
        _showBriefToast('Could not load classes. Using defaults.');
      }
    }
  }

  // Toggle label selection
  void _toggleLabel(String label) {
    setState(() {
      if (_labels.contains(label)) {
        _labels.remove(label);
      } else {
        _labels.add(label);
      }
    });
    
    // Save draft whenever we toggle labels
    _saveDraftLocally();
  }

  // Save offline product to SharedPreferences
  Future<void> _saveOfflineProduct(ProductModel product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get the current list of offline products
      List<String> offlineProducts = prefs.getStringList('offline_products') ?? [];
      
      // Convert the product to JSON
      final productJson = jsonEncode(product.toJson());
      
      // Add to the list
      offlineProducts.add(productJson);
      
      // Save the updated list
      await prefs.setStringList('offline_products', offlineProducts);
      print("Product saved offline: ${product.title}");
    } catch (e) {
      print("Error saving product offline: $e");
      // At least save as draft
      await _saveDraftLocally();
    }
  }

  String? _getClassIdFromName(String className) {
    if (className == "No class") return null;
    
    for (var classItem in _availableClasses) {
      if (classItem['name'] == className || classItem['id'] == className) {
        return classItem['id'];
      }
    }
    return null;
  }
Future<void> _submitForm() async {
  // Validaciones
  if (_titleController.text.trim().isEmpty) {
    _showErrorAlert('Por favor ingresa un título');
    return;
  }
  if (_descriptionController.text.trim().isEmpty) {
    _showErrorAlert('Por favor ingresa una descripción');
    return;
  }
  final price = double.tryParse(_priceController.text.trim());
  if (price == null) {
    _showErrorAlert('Por favor ingresa un precio válido');
    return;
  }
  if (_productImage == null) {
    _showErrorAlert('Por favor agrega al menos una imagen del producto');
    return;
  }

  setState(() {
    _isLoading = true;
    _isUploading = true;
  });

  try {
    // Mostrar diálogo de carga
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return CupertinoAlertDialog(
              title: const Text("Subiendo Producto"),
              content: Column(
                children: [
                  const SizedBox(height: 20),
                  const CupertinoActivityIndicator(radius: 15),
                  const SizedBox(height: 20),
                  Text(
                    "Preparando información del producto...",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Construcción del modelo
    final now = DateTime.now();
    final productModel = ProductModel(
      id: null,
      title: _titleController.text.trim(),
      price: price,
      description: _descriptionController.text.trim(),
      classId: _selectedClass != "No class"
          ? _getClassIdFromName(_selectedClass) ?? ''
          : '',
      createdAt: now,
      imageUrls: [],
      pendingImagePaths: [_productImage!.path],
      labels: _labels,
      majorID: _selectedMajor != "No major" ? _selectedMajor : '',
      sellerID: _firebaseDAO.getCurrentUserId() ?? '',
      status: 'Available',
      updatedAt: now,
    );

    // Siempre encolamos el producto
    final queueId = await _productService.createProduct(productModel);
    
    // Cerrar diálogo de carga
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    _showSuccessDialogOffline(
      'Producto en cola',
      'Se guardó y se subirá automáticamente.',
    );
    await _clearDraft();
    
  } catch (e) {
    // Cerrar diálogo de carga en caso de error
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    _showErrorAlert('Error al procesar: $e');
  } finally {
    if (mounted) setState(() {
      _isLoading = false;
      _isUploading = false;
    });
  }
}

  // Handle offline product saving
  Future<void> _saveProductOffline() async {
    final now = DateTime.now();
    String? userId = _firebaseDAO.getCurrentUserId();
    
    // List of local image paths
    List<String> localImagePaths = [];
    if (_productImage != null) {
      localImagePaths.add(_productImage!.path);
    }
    
    // Prepare product data for the queue
    ProductModel newProduct = ProductModel(
      id: null,
      title: _titleController.text.trim(),
      price: double.parse(_priceController.text.trim()),
      description: _descriptionController.text.trim(),
      classId: _selectedClass != "No class" ? _getClassIdFromName(_selectedClass) ?? '' : '',
      createdAt: now,
      imageUrls: [],
      pendingImagePaths: localImagePaths,
      labels: _labels,
      majorID: _selectedMajor != "No major" ? _selectedMajor : '',
      sellerID: userId ?? '',
      status: 'Available',
      updatedAt: now,
    );
    
    // Store in SharedPreferences for later sync
    await _saveOfflineProduct(newProduct);
  }


Future<void> _uploadProductOnline() async {
  final String filePath = _productImage!.path;
  debugPrint('📁 Archivo a subir: $filePath');

  // IMPORTANT CHANGE: Use _uploadImageWithRetries instead of direct call
  String? downloadUrl = await _uploadImageWithRetries(filePath);
  debugPrint('⬆️ uploadImageWithRetries result: $downloadUrl');

  if (downloadUrl == null) {
    debugPrint('⚠️ downloadUrl es null, deteniendo proceso.');
    
    // Check if we went offline during upload
    final bool hasConnection = await _connectivityService.checkConnectivity();
    if (!hasConnection) {
      debugPrint('📵 Device went offline during upload, saving to queue');
      setState(() => _isOffline = true);
      await _saveProductOffline();
      _showSuccessDialogOffline(
        'Producto en cola',
        'Tu producto se guardó localmente para subirlo más tarde.'
      );
      return;
    }
    
    _showErrorAlert('No se pudo subir la imagen. Intenta de nuevo.');
    return;
  }

  // Rest of your product creation code remains the same
  debugPrint('📝 Preparando datos del producto con imageUrl');
  final Map<String, dynamic> productData = {
    'title':       _titleController.text.trim(),
    'description': _descriptionController.text.trim(),
    'price':       int.parse(_priceController.text.trim()),
    'sellerID':    _firebaseDAO.getCurrentUserId(),
    'status':      'Available',
    'createdAt':   FieldValue.serverTimestamp(),
    'updatedAt':   FieldValue.serverTimestamp(),
    'labels':      _labels,
    'imageUrls':   [downloadUrl],
  };
  if (_selectedMajor != 'No major') productData['majorID'] = _selectedMajor;
  if (_selectedClass != 'No class') {
    final cid = _getClassIdFromName(_selectedClass);
    if (cid != null) productData['classID'] = cid;
  }

  String? productId;
  try {
    debugPrint('📡 Iniciando createProduct con timeout 10s');
    productId = await _firebaseDAO
      .createProduct(productData)
      .timeout(const Duration(seconds: 10));
    debugPrint('📡 createProduct result: $productId');
  } on TimeoutException {
    debugPrint('⏱️ TimeoutException en createProduct');
    setState(() => _isOffline = true);
  } catch (e, st) {
    debugPrint('🚨 Error creando producto: $e\n$st');
    _showErrorAlert('Error al crear el producto: $e');
  }

  if (productId != null) {
    debugPrint('✅ Producto creado con ID: $productId');
    _showSuccessAlert('¡Producto subido exitosamente!');
    await _clearDraft();
    _saveImageToGallery(_productImage!);
  } else {
    debugPrint('⚠️ productId es null, guardando offline');
    await _saveProductOffline();
    _showSuccessDialogOffline(
      'Producto en cola',
      'Tu producto se guardó localmente para subirlo más tarde.'
    );
  }
}

  // Dialog to offer saving offline when upload fails
  void _showOfflineSaveDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('No Connection'),
        content: Text('Could not create the product. Do you want to save it locally to upload later?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('Cancel'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoDialogAction(
            child: Text('Save in Queue'),
            onPressed: () {
              Navigator.pop(context);
              // Switch to offline mode and retry
              setState(() {
                _isOffline = true;
              });
              _submitForm();
            },
          ),
        ],
      ),
    );
  }

  // Dialog for offline success
  void _showSuccessDialogOffline(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),
            Icon(
              CupertinoIcons.arrow_up_doc,
              color: AppColors.primaryBlue,
              size: 50,
            ),
            SizedBox(height: 16),
            Text(message),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: Text("View Queue"),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => QueuedProductsScreen(),
                ),
              );
            },
          ),
          CupertinoDialogAction(
            child: Text("Close"),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Show error alert
  void _showErrorAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Show success alert
  void _showSuccessAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to previous screen
            },
          ),
        ],
      ),
    );
  }



Future<String?> _uploadImageWithRetries(String filePath) async {
  bool dialogShown = false;
  
  try {
    // Mostrar diálogo con mensaje inicial
    dialogShown = true;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return CupertinoAlertDialog(
              title: const Text("Subiendo Producto"),
              content: Column(
                children: [
                  const SizedBox(height: 20),
                  const CupertinoActivityIndicator(radius: 15),
                  const SizedBox(height: 20),
                  Text(
                    "Verificando conexión a internet...",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text("Cancelar"),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    dialogShown = false;
                  },
                ),
              ],
            );
          },
        );
      },
    );

    // Actualizar mensaje para subida de imagen
    if (dialogShown && mounted) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              return CupertinoAlertDialog(
                title: const Text("Subiendo Producto"),
                content: Column(
                  children: [
                    const SizedBox(height: 20),
                    const CupertinoActivityIndicator(radius: 15),
                    const SizedBox(height: 20),
                    Text(
                      "Subiendo imágenes...",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: const Text("Cancelar"),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      dialogShown = false;
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    }
    
    // Usar timeout para la subida
    final String? result = await _firebaseDAO.uploadProductImage(filePath)
        .timeout(const Duration(seconds: 15));
    
    // Cerrar diálogo
    if (dialogShown && mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    return result;
  } on TimeoutException {
    debugPrint("Upload timed out after 15 seconds");
    // Cerrar diálogo en timeout
    if (dialogShown && mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    return null;
  } catch (e) {
    debugPrint("Error uploading image: $e");
    // Cerrar diálogo en error
    if (dialogShown && mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    return null;
  }
}

void _navigateToQueueScreen() {
  Navigator.of(context).push(
    CupertinoPageRoute(builder: (_) => const QueuedProductsScreen()),
  );
}

Widget _buildViewQueueButton() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    child: CupertinoButton(
      color: AppColors.primaryBlue,
      onPressed: _navigateToQueueScreen,
      child: const Text('Ver Cola'),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Upload Product'),
      ),
      child: Column(
        children: [
          // Offline mode indicator
          if (_isOffline)
            Container(
              width: double.infinity,
              color: CupertinoColors.systemYellow.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.wifi_slash,
                    color: CupertinoColors.systemYellow,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Offline mode: the product will be saved in queue until you are back online.",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image Selection Section
                          const Text('Product Image',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _navigateToCameraScreen,
                            child: Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: CupertinoColors.systemGrey4),
                              ),
                              child: _productImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        _productImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          CupertinoIcons.camera,
                                          size: 50,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Tap to take a photo',
                                          style: TextStyle(
                                              color: CupertinoColors.systemGrey),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Measurements Preview
                          if (_productImage != null && _measurementTexts.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey6,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: CupertinoColors.systemGrey4),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(CupertinoIcons.info,
                                              size: 16,
                                              color: AppColors.primaryBlue),
                                          SizedBox(width: 6),
                                          Text(
                                            'Captured Measurements:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: _measurementTexts
                                            .map(
                                              (measure) => Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryBlue
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: AppColors.primaryBlue
                                                        .withOpacity(0.5),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  measure,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.primaryBlue,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16),
                              ],
                            ),
                          
                          // Title
                          const Text('Product Title *',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: _titleController,
                            placeholder: 'Enter a descriptive title',
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: CupertinoColors.systemGrey4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Description
                          const Text('Description *',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: _descriptionController,
                            placeholder: 'Describe your product in detail',
                            padding: const EdgeInsets.all(12),
                            maxLines: 5,
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: CupertinoColors.systemGrey4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Price
                          const Text('Price (COP) *',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: _priceController,
                            placeholder: 'Enter price in COP',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text('\$ '),
                            ),
                            padding: const EdgeInsets.all(12),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: false),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: CupertinoColors.systemGrey4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Major selection
                          const Text('Major',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: CupertinoColors.systemGrey4),
                              borderRadius: BorderRadius.circular(8),
                              color: CupertinoColors.systemGrey6,
                            ),
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                showCupertinoModalPopup(
                                  context: context,
                                  builder: (BuildContext context) => Container(
                                    height: 200,
                                    padding: const EdgeInsets.only(top: 6.0),
                                    margin: EdgeInsets.only(
                                      bottom: MediaQuery.of(context)
                                          .viewInsets
                                          .bottom,
                                    ),
                                    color: CupertinoColors.systemBackground,
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            CupertinoButton(
                                              child: const Text('Cancel'),
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                            ),
                                            CupertinoButton(
                                              child: const Text('Done'),
                                              onPressed: () {
                                                final String selectedMajor =
                                                    _tempSelectedMajor ??
                                                        _selectedMajor;
                                                setState(() {
                                                  _selectedMajor = selectedMajor;
                                                });
                                                _fetchClassesForMajor(
                                                    selectedMajor);
                                                Navigator.pop(context);
                                                // Save draft after changing major
                                                _saveDraftLocally();
                                              },
                                            ),
                                          ],
                                        ),
                                        Container(
                                            height: 1,
                                            color: CupertinoColors.systemGrey5),
                                        Expanded(
                                          child: CupertinoPicker(
                                            magnification: 1.22,
                                            squeeze: 1.2,
                                            useMagnifier: true,
                                            itemExtent: 32,
                                            onSelectedItemChanged: (int index) {
                                              _tempSelectedMajor =
                                                  _availableMajors[index];
                                            },
                                            children: _availableMajors
                                                .map((String major) =>
                                                    Center(child: Text(major)))
                                                .toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Text(
                                      _selectedMajor,
                                      style: const TextStyle(
                                        color: CupertinoColors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: Icon(
                                      CupertinoIcons.chevron_down,
                                      color: CupertinoColors.systemGrey,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Class selection
                          if (_selectedMajor != "No major") ...[
                            const Text('Class',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _isClassLoading
                                ? const Center(
                                    child: CupertinoActivityIndicator())
                                : Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: CupertinoColors.systemGrey4),
                                      borderRadius: BorderRadius.circular(8),
                                      color: CupertinoColors.systemGrey6,
                                    ),
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        showCupertinoModalPopup(
                                          context: context,
                                          builder: (BuildContext context) =>
                                              Container(
                                            height: 200,
                                            padding:
                                                const EdgeInsets.only(top: 6.0),
                                            margin: EdgeInsets.only(
                                              bottom: MediaQuery.of(context)
                                                  .viewInsets
                                                  .bottom,
                                            ),
                                            color:
                                                CupertinoColors.systemBackground,
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    CupertinoButton(
                                                      child:
                                                          const Text('Cancel'),
                                                      onPressed: () =>
                                                          Navigator.pop(context),
                                                    ),
                                                    CupertinoButton(
                                                      child: const Text('Done'),
                                                      onPressed: () =>
                                                          Navigator.pop(context),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  height: 1,
                                                  color: CupertinoColors
                                                      .systemGrey5,
                                                ),
                                                Expanded(
                                                  child: CupertinoPicker(
                                                    magnification: 1.22,
                                                    squeeze: 1.2,
                                                    useMagnifier: true,
                                                    itemExtent: 32,
                                                    onSelectedItemChanged:
                                                        (int index) {
                                                      setState(() {
                                                        _selectedClass =
                                                            _availableClassNames[
                                                                index];
                                                      });
                                                      // Save draft after changing class
                                                      _saveDraftLocally();
                                                    },
                                                    children:
                                                        _availableClassNames
                                                            .map((String
                                                                    className) =>
                                                                Center(
                                                                    child: Text(
                                                                        className)))
                                                            .toList(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 12),
                                            child: Text(
                                              _selectedClass,
                                              style: const TextStyle(
                                                color: CupertinoColors.black,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          const Padding(
                                            padding:
                                                EdgeInsets.only(right: 12),
                                            child: Icon(
                                              CupertinoIcons.chevron_down,
                                              color: CupertinoColors.systemGrey,
                                              size: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Labels section
                          const Text(
                            'Categories/Labels',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _availableLabels.map((label) {
                              final isSelected = _labels.contains(label);
                              return GestureDetector(
                                onTap: () => _toggleLabel(label),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryBlue
                                        : CupertinoColors.systemGrey6,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primaryBlue
                                          : CupertinoColors.systemGrey4,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? CupertinoColors.white
                                          : CupertinoColors.black,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),

    // Submit button
    SizedBox(
      width: double.infinity,
      height: 50,
      child: CupertinoButton(
      padding: EdgeInsets.zero,
      color: CupertinoColors.white,
      borderRadius: BorderRadius.circular(8),
      onPressed: _navigateToQueueScreen,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.primaryBlue,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Text(
        'Recent Uploads',
        style: TextStyle(
          color: AppColors.primaryBlue,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        ),
      ),
      ),
    ),
                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(8),
                              onPressed: _isUploading ? null : _submitForm,
                              child: _isUploading
                                  ? CupertinoActivityIndicator(color: CupertinoColors.white)
                                  : const Text(
                                      'Upload Product',
                                      style: TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}