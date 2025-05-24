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
import 'package:unimarket/data/image_storage_service.dart';

class UploadProductScreen extends StatefulWidget {
  const UploadProductScreen({super.key});

  @override
  UploadProductScreenState createState() => UploadProductScreenState();
}

class UploadProductScreenState extends State<UploadProductScreen> {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  final ImageStorageService _imageStorage = ImageStorageService();
  String? _tempSelectedMajor;
  bool _isClassLoading = false;
  File? _productImage;
  String? _imageUrl;
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isOffline = false;
  final ProductService _productService = ProductService();
  MeasurementData? _measurementData;
  List<String> _measurementTexts = [];

  // Límites de caracteres
  final int _maxCharLength = 100;
  final int _maxPriceLength = 10;
  int _titleLength = 0;
  int _descriptionLength = 0;
  int _priceLength = 0;

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
  bool _isUploading = false;
  List<String> _availableMajors = ["No major"];
  List<Map<String, dynamic>> _availableClasses = [];
  List<String> _availableClassNames = ["No class"];

  Timer? _uploadTimer;

  @override
  void initState() {
    super.initState();
    
    // Initialize image storage
    _imageStorage.initialize();
    
    _availableMajors = ["No major"];
    _checkConnectivityAndLoad();
    
    Future.delayed(Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        debugPrint('⚠️ Forced exit from loading state after timeout');
        setState(() {
          _isLoading = false;
        });
      }
    });
    
    _connectivityService.connectivityStream.listen((hasInternet) {
      if (mounted) {
        setState(() {
          _isOffline = !hasInternet;
        });
      }
    });
    
    // Agregar listeners para el contador de caracteres
    _titleController.addListener(() {
      if (_titleController.text.length > _maxCharLength) {
        _titleController.text = _titleController.text.substring(0, _maxCharLength);
        _titleController.selection = TextSelection.fromPosition(
          TextPosition(offset: _maxCharLength)
        );
        _showCharLimitAlert();
      }
      setState(() {
        _titleLength = _titleController.text.length;
      });
      _saveDraftLocally();
    });
    
    _descriptionController.addListener(() {
      if (_descriptionController.text.length > _maxCharLength) {
        _descriptionController.text = _descriptionController.text.substring(0, _maxCharLength);
        _descriptionController.selection = TextSelection.fromPosition(
          TextPosition(offset: _maxCharLength)
        );
        _showCharLimitAlert();
      }
      setState(() {
        _descriptionLength = _descriptionController.text.length;
      });
      _saveDraftLocally();
    });
    
    _priceController.addListener(() {
      if (_priceController.text.length > _maxPriceLength) {
        _priceController.text = _priceController.text.substring(0, _maxPriceLength);
        _priceController.selection = TextSelection.fromPosition(
          TextPosition(offset: _maxPriceLength)
        );
        _showPriceLimitAlert();
      }
      
      // Validar que solo contenga números y un punto decimal
      String value = _priceController.text;
      if (value.isNotEmpty) {
        // Remover el símbolo de peso si existe
        value = value.replaceAll('\$', '').trim();
        
        // Validar formato
        if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(value)) {
          // Si no coincide con el formato, revertir al último valor válido
          _priceController.text = value.replaceAll(RegExp(r'[^\d.]'), '');
          _priceController.selection = TextSelection.fromPosition(
            TextPosition(offset: _priceController.text.length)
          );
        }
      }
      
      setState(() {
        _priceLength = _priceController.text.length;
      });
      _saveDraftLocally();
    });
  }

  Future<void> _checkConnectivityAndLoad() async {
    await _loadDraftIfAny();
    
    final bool hasInternet = await _connectivityService.checkConnectivity();
    
    if (mounted) {
      setState(() {
        _isOffline = !hasInternet;
      });
      
      if (hasInternet) {
        _fetchAvailableMajors();
      }
    }
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();
    
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    
    _titleController.removeListener(() {
      setState(() {
        _titleLength = _titleController.text.length;
        if (_titleLength > _maxCharLength) {
          _titleController.text = _titleController.text.substring(0, _maxCharLength);
          _titleController.selection = TextSelection.fromPosition(
            TextPosition(offset: _maxCharLength)
          );
        }
      });
      _saveDraftLocally();
    });
    
    _descriptionController.removeListener(() {
      setState(() {
        _descriptionLength = _descriptionController.text.length;
        if (_descriptionLength > _maxCharLength) {
          _descriptionController.text = _descriptionController.text.substring(0, _maxCharLength);
          _descriptionController.selection = TextSelection.fromPosition(
            TextPosition(offset: _maxCharLength)
          );
        }
      });
      _saveDraftLocally();
    });
    
    _priceController.removeListener(() {
      setState(() {
        _priceLength = _priceController.text.length;
        if (_priceLength > _maxPriceLength) {
          _priceController.text = _priceController.text.substring(0, _maxPriceLength);
          _priceController.selection = TextSelection.fromPosition(
            TextPosition(offset: _maxPriceLength)
          );
        }
      });
      _saveDraftLocally();
    });
    
    super.dispose();
  }

  // MEJORADO: Cargar draft con mejor manejo de imágenes
  Future<void> _loadDraftIfAny() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final storedPath = prefs.getString('draft_image_path');
      final storedTitle = prefs.getString('draft_title') ?? '';
      final storedDesc = prefs.getString('draft_desc') ?? '';
      final storedPrice = prefs.getString('draft_price') ?? '';
      final storedMajor = prefs.getString('draft_major') ?? 'No major';
      final storedClass = prefs.getString('draft_class') ?? 'No class';
      final storedLabels = prefs.getStringList('draft_labels') ?? [];
      
      File? loadedImage;
      if (storedPath != null && storedPath.isNotEmpty) {
        final tempFile = File(storedPath);
        
        // Verificar si la imagen existe
        if (await tempFile.exists()) {
          loadedImage = tempFile;
          debugPrint('✅ Draft image loaded successfully: $storedPath');
        } else {
          debugPrint('⚠️ Draft image file not found: $storedPath');
          // Limpiar la ruta inválida del draft
          await prefs.remove('draft_image_path');
        }
      }
      
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
      
      if (_selectedMajor != "No major") {
        await _fetchClassesForMajor(_selectedMajor);
      }
    } catch (e) {
      debugPrint("Error loading draft: $e");
    }
  }

  // MEJORADO: Guardar draft con mejor validación
  Future<void> _saveDraftLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('draft_title', _titleController.text.trim());
      await prefs.setString('draft_desc', _descriptionController.text.trim());
      await prefs.setString('draft_price', _priceController.text.trim());
      await prefs.setString('draft_major', _selectedMajor);
      await prefs.setString('draft_class', _selectedClass);
      await prefs.setStringList('draft_labels', _labels);
      
      // Solo guardar la ruta de imagen si existe y es válida
      if (_productImage != null && await _productImage!.exists()) {
        await prefs.setString('draft_image_path', _productImage!.path);
        debugPrint('💾 Draft saved with image: ${_productImage!.path}');
      } else {
        await prefs.remove('draft_image_path');
        debugPrint('💾 Draft saved without image');
      }
    } catch (e) {
      debugPrint("Error saving draft: $e");
    }
  }

  // MEJORADO: Limpiar draft completamente
  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_title');
      await prefs.remove('draft_desc');
      await prefs.remove('draft_price');
      await prefs.remove('draft_major');
      await prefs.remove('draft_class');
      await prefs.remove('draft_labels');
      await prefs.remove('draft_image_path');
      
      debugPrint('🧹 Draft cleared completely');
    } catch (e) {
      debugPrint("Error clearing draft: $e");
    }
  }

  Future<void> _saveImageToGallery(File imageFile) async {
    try {
      final result = await ImageGallerySaver.saveFile(imageFile.path);
      if (result['isSuccess'] == true) {
        debugPrint("Image saved to gallery: ${result['filePath']}");
      } else {
        debugPrint("Failed to save image to gallery");
      }
    } catch (e) {
      debugPrint("Error saving image to gallery: $e");
    }
  }

  // MEJORADO: Guardar imagen en directorio temporal del draft
  Future<File> _saveImageLocally(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final draftDir = Directory('${directory.path}/draft_images');
      
      // Crear directorio si no existe
      if (!await draftDir.exists()) {
        await draftDir.create(recursive: true);
      }
      
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final localPath = p.join(draftDir.path, fileName);
      final savedFile = await imageFile.copy(localPath);
      
      debugPrint('📸 Image saved to draft directory: $localPath');
      return savedFile;
    } catch (e) {
      debugPrint('🚨 Error saving image locally: $e');
      rethrow;
    }
  }

  // MEJORADO: Manejar imagen capturada
  void _handleImageCaptured(File image, MeasurementData? measurementData) async {
    try {
      // Guardar la imagen en el directorio temporal de draft
      final localImage = await _saveImageLocally(image);
      
      if (mounted) {
        setState(() {
          _productImage = localImage;
          _imageUrl = null;
          _measurementData = measurementData;
          
          _measurementTexts = [];
          if (measurementData != null && measurementData.lines.isNotEmpty) {
            for (var line in measurementData.lines) {
              _measurementTexts.add(line.measurement);
            }
            
            if (_measurementTexts.isNotEmpty) {
              String currentDescription = _descriptionController.text;
              String measurementsText = "\n\nMeasurements:\n- ${_measurementTexts.join("\n- ")}";
              
              if (!currentDescription.contains("Measurements:")) {
                _descriptionController.text = currentDescription + measurementsText;
              }
            }
          }
        });
      }
      
      // Guardar draft inmediatamente después de capturar imagen
      await _saveDraftLocally();
      debugPrint('✅ Image captured and draft saved');
    } catch (e) {
      debugPrint("Error handling captured image: $e");
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
    if (!mounted) {
      debugPrint('🔍 _fetchAvailableMajors: widget ya desmontado, abortando');
      return;
    }

    debugPrint('🔍 _fetchAvailableMajors: iniciando, marcando isLoading=true');
    setState(() {
      _isLoading = true;
    });

    try {
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

      debugPrint('📡 _fetchAvailableMajors: solicitando majors a Firestore');
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('majors')
          .get()
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ _fetchAvailableMajors: recibidos ${querySnapshot.docs.length} majors');

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

  void _showBriefToast(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        content: Text(message),
      ),
    );

    Future.delayed(Duration(seconds: 2), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

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

  void _toggleLabel(String label) {
    setState(() {
      if (_labels.contains(label)) {
        _labels.remove(label);
      } else {
        _labels.add(label);
      }
    });
    
    _saveDraftLocally();
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

  // MEJORADO: Submit form con mejor manejo de imágenes
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


    // Verificar que la imagen existe antes de continuar
    if (!await _productImage!.exists()) {
      _showErrorAlert('Error: La imagen seleccionada no existe. Por favor toma una nueva foto.');
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
        pendingImagePaths: [_productImage!.path], // Usar la ruta actual de la imagen
        labels: _labels,
        majorID: _selectedMajor != "No major" ? _selectedMajor : '',
        sellerID: _firebaseDAO.getCurrentUserId() ?? '',
        status: 'Available',
        updatedAt: now,
      );

      debugPrint('📦 Creating product with image: ${_productImage!.path}');
      debugPrint('🔍 Image exists: ${await _productImage!.exists()}');
      
      // Encolar el producto
      final queueId = await _productService.createProduct(productModel);
      
      // Cerrar diálogo de carga
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      _showSuccessDialogOffline(
        'Producto en cola',
        'Se guardó y se subirá automáticamente.',
      );
      
      // Limpiar todo después del éxito
      await _clearDraft();
      
      // Limpiar el estado del formulario
      if (mounted) {
        setState(() {
          _productImage = null;
          _measurementData = null;
          _measurementTexts = [];
          _titleController.clear();
          _descriptionController.clear();
          _priceController.clear();
          _selectedMajor = "No major";
          _selectedClass = "No class";
          _labels.clear();
        });
      }
      
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
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _navigateToQueueScreen() {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const QueuedProductsScreen()),
    );
  }

  void _showCharLimitAlert() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text("Character Limit Reached"),
        content: Text("Please keep your input under $_maxCharLength characters."),
        actions: [
          CupertinoDialogAction(
            child: Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showPriceLimitAlert() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text("Price Limit Reached"),
        content: Text("Please keep your input under $_maxPriceLength characters."),
        actions: [
          CupertinoDialogAction(
            child: Text("OK"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CupertinoTextField(
                                controller: _titleController,
                                placeholder: 'Enter a descriptive title',
                                padding: const EdgeInsets.all(12),
                                maxLength: _maxCharLength,
                                decoration: BoxDecoration(
                                  border: Border.all(color: CupertinoColors.systemGrey4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 4),
                                child: Text(
                                  "$_titleLength/$_maxCharLength",
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: _titleLength >= _maxCharLength
                                        ? CupertinoColors.systemRed
                                        : CupertinoColors.systemGrey
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Description
                          const Text('Description *',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CupertinoTextField(
                                controller: _descriptionController,
                                placeholder: 'Describe your product in detail',
                                padding: const EdgeInsets.all(12),
                                maxLines: 5,
                                maxLength: _maxCharLength,
                                decoration: BoxDecoration(
                                  border: Border.all(color: CupertinoColors.systemGrey4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 4),
                                child: Text(
                                  "$_descriptionLength/$_maxCharLength",
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: _descriptionLength >= _maxCharLength
                                        ? CupertinoColors.systemRed
                                        : CupertinoColors.systemGrey
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Price
                          const Text('Price (COP) *',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CupertinoTextField(
                                controller: _priceController,
                                placeholder: 'Enter price in COP',
                                prefix: const Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Text('\$ '),
                                ),
                                padding: const EdgeInsets.all(12),
                                maxLength: _maxPriceLength,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: BoxDecoration(
                                  border: Border.all(color: CupertinoColors.systemGrey4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 4),
                                child: Text(
                                  "$_priceLength/$_maxPriceLength",
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: _priceLength >= _maxPriceLength
                                        ? CupertinoColors.systemRed
                                        : CupertinoColors.systemGrey
                                  ),
                                ),
                              ),
                            ],
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

                          // Recent uploads button
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

                          // Submit button
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