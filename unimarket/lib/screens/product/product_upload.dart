import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/measurement_model.dart';
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
  List<String> _availableMajors = ["No major"];
  List<Map<String, dynamic>> _availableClasses = [];
  List<String> _availableClassNames = ["No class"];

  @override
  void initState() {
    super.initState();
    _fetchAvailableMajors();

    // NEW CODE: Load any existing draft when the screen initializes
    _loadDraftIfAny();

    // NEW CODE: Listen for text changes so we can save the draft
    _titleController.addListener(_saveDraftLocally);
    _descriptionController.addListener(_saveDraftLocally);
    _priceController.addListener(_saveDraftLocally);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // NEW CODE: Helper to load any local draft from SharedPreferences
  Future<void> _loadDraftIfAny() async {
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

    // If major != "No major", re-fetch classes
    if (_selectedMajor != "No major") {
      await _fetchClassesForMajor(_selectedMajor);
    }
  }

  // NEW CODE: Helper to save (or update) a draft in SharedPreferences
  Future<void> _saveDraftLocally() async {
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
  }

  // NEW CODE: Clear all draft data after successful upload
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

  // NEW CODE: Save image to the device's photo library (iOS camera roll)
  Future<void> _saveImageToGallery(File imageFile) async {
    // For iOS, you'll need "NSPhotoLibraryAddUsageDescription" in Info.plist
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

  // Helper method to store the image file in the app’s Documents directory
  Future<File> _saveImageLocally(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final localPath = p.join(directory.path, fileName);
    return imageFile.copy(localPath);
  }

  // Handle image capture from camera screen
  void _handleImageCaptured(File image, MeasurementData? measurementData) async {
    final localImage = await _saveImageLocally(image);

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
          String measurementsText =
              "\n\nMeasurements:\n- " + _measurementTexts.join("\n- ");

          // Only add if not already there
          if (!currentDescription.contains("Measurements:")) {
            _descriptionController.text = currentDescription + measurementsText;
          }
        }
      }
    });

    // NEW CODE: Whenever we get a new image, also save the draft
    _saveDraftLocally();
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

  // Fetch majors from Firestore
  Future<void> _fetchAvailableMajors() async {
    setState(() {
      _isLoading = true;
    });
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('majors').get();
      List<String> majors = ["No major"];
      for (var doc in querySnapshot.docs) {
        majors.add(doc.id);
      }
      setState(() {
        _availableMajors = majors;
      });
    } catch (e) {
      _showErrorAlert('Error loading majors: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
    setState(() {
      _isClassLoading = true;
    });

    try {
      List<Map<String, dynamic>> classes =
          await _firebaseDAO.getClassesForMajor(majorId);
      List<String> classNames = ["No class"];
      for (var classItem in classes) {
        classNames.add(classItem['name'] ?? classItem['id']);
      }
      setState(() {
        _availableClasses = classes;
        _availableClassNames = classNames;
        _selectedClass = "No class";
      });
    } catch (e) {
      _showErrorAlert('Error loading classes: $e');
    } finally {
      setState(() {
        _isClassLoading = false;
      });
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

  Future<void> _submitForm() async {
    // Basic validations
    if (_titleController.text.trim().isEmpty) {
      _showErrorAlert('Please enter a title');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showErrorAlert('Please enter a description');
      return;
    }
    if (_priceController.text.trim().isEmpty ||
        int.tryParse(_priceController.text.trim()) == null) {
      _showErrorAlert('Please enter a valid price');
      return;
    }
    if (_productImage == null) {
      _showErrorAlert('Please add at least one product image');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload image to Firebase
      String? downloadUrl;
      if (_productImage != null) {
        final String filePath = _productImage!.path;
        final File imageFile = File(filePath);

        final bool exists = await imageFile.exists();
        final int fileSize = exists ? await imageFile.length() : 0;
        print(
            "Uploading file from path: $filePath, exists: $exists, size: $fileSize bytes");

        if (!exists) {
          _showErrorAlert('Image file does not exist at $filePath');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Show a loading dialog
        showCupertinoDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoActivityIndicator(),
                  SizedBox(height: 15),
                  Text("Uploading image..."),
                ],
              ),
            ),
          ),
        );

        downloadUrl = await _firebaseDAO.uploadProductImage(filePath);

        Navigator.of(context).pop(); // Close the "Uploading" dialog

        if (downloadUrl == null) {
          _showErrorAlert('Failed to upload product image');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Prepare product data
      Map<String, dynamic> productData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': int.parse(_priceController.text.trim()),
        'sellerID': _firebaseDAO.getCurrentUserId(),
        'status': 'Available',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'labels': _labels,
      };

      // Add image URL if available
      if (downloadUrl != null) {
        productData['imageUrls'] = [downloadUrl];
      }

      // Add majorID if selected
      if (_selectedMajor != "No major") {
        productData['majorID'] = _selectedMajor;
      }

      // Add classID if selected
      if (_selectedClass != "No class") {
        String? classId;
        for (var classItem in _availableClasses) {
          if (classItem['name'] == _selectedClass ||
              classItem['id'] == _selectedClass) {
            classId = classItem['id'];
            break;
          }
        }
        if (classId != null) {
          productData['classID'] = classId;
        }
      }

      // Add measurement data if available
      if (_measurementData != null && _measurementData!.lines.isNotEmpty) {
        List<Map<String, dynamic>> simplifiedMeasurements = [];
        for (var line in _measurementData!.lines) {
          simplifiedMeasurements.add({
            'value': line.measurement,
            'fromPoint': {
              'x': line.from.x,
              'y': line.from.y,
              'z': line.from.z
            },
            'toPoint': {
              'x': line.to.x,
              'y': line.to.y,
              'z': line.to.z
            },
          });
        }
        productData['measurementCount'] = simplifiedMeasurements.length;
      }

      // Update product placement metrics
      _firebaseDAO.updateProductPlacementMetrics(_labels);

      // Create product in Firestore
      final productId = await _firebaseDAO.createProduct(productData);

      if (productId != null) {
        // SUCCESS:
        _showSuccessAlert('Product uploaded successfully!');

        // NEW CODE: After successful upload, clear the local draft
        await _clearDraft();

        // NEW CODE: Optionally save the photo to iOS Camera Roll
        if (_productImage != null) {
          _saveImageToGallery(_productImage!);
        }
      } else {
        _showErrorAlert('Failed to upload product');
      }
    } catch (e) {
      _showErrorAlert('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to previous screen
            },
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
                          border: Border.all(color: CupertinoColors.systemGrey4),
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
                              border:
                                  Border.all(color: CupertinoColors.systemGrey4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(CupertinoIcons.info,
                                        size: 16, color: AppColors.primaryBlue),
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
                        border: Border.all(color: CupertinoColors.systemGrey4),
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
                        border: Border.all(color: CupertinoColors.systemGrey4),
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: false),
                      decoration: BoxDecoration(
                        border: Border.all(color: CupertinoColors.systemGrey4),
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
                        border: Border.all(color: CupertinoColors.systemGrey4),
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
                                bottom:
                                    MediaQuery.of(context).viewInsets.bottom,
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
                                        onPressed: () => Navigator.pop(context),
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
                                          _fetchClassesForMajor(selectedMajor);
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          ? const Center(child: CupertinoActivityIndicator())
                          : Container(
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
                                                onPressed: () => Navigator.pop(context),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            height: 1,
                                            color: CupertinoColors.systemGrey5,
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
                                              children: _availableClassNames
                                                  .map((String className) =>
                                                      Center(child: Text(className)))
                                                  .toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(
                                        _selectedClass,
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
                    ],

                    // Labels section
                    const Text(
                      'Categories/Labels',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(8),
                        onPressed: _submitForm,
                        child: const Text(
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
    );
  }
}
