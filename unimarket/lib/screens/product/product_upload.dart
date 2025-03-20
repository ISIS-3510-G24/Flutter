import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/models/class_model.dart'; // You'll need to create this

class UploadProductScreen extends StatefulWidget {
  const UploadProductScreen({Key? key}) : super(key: key);

  @override
  _UploadProductScreenState createState() => _UploadProductScreenState();
}

class _UploadProductScreenState extends State<UploadProductScreen> {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  String? _tempSelectedMajor; // Temporarily store selected major
  bool _isClassLoading = false;
  
  // Form fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  
  String _selectedMajor = "No major"; // Default value
  String _selectedClass = "No class"; // Default value for class
  List<String> _labels = []; // Store selected labels
  final List<String> _availableLabels = [
  "Academics","Education","Technology", "Electronics","Art","Design","Engineering",
  "Handcrafts","Fashion","Accessories","Sports","Wellness","Entertainment","Home","Decoration","Other"
  ];
  
  bool _isLoading = false;
  List<String> _availableMajors = ["No major"]; // Will be populated from Firestore
  List<Map<String, dynamic>> _availableClasses = []; // Will be populated based on selected major
  List<String> _availableClassNames = ["No class"]; // Class names for the picker
  
  @override
  void initState() {
    super.initState();
    _fetchAvailableMajors();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }
  
  // Fetch majors from Firestore
  Future<void> _fetchAvailableMajors() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('majors').get();
      
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
    _isClassLoading = true; // Only set class loading to true, not the entire screen
  });
  
  try {
    List<Map<String, dynamic>> classes = await _firebaseDAO.getClassesForMajor(majorId);
    
    // Extract class names and add default option
    List<String> classNames = ["No class"];
    for (var classItem in classes) {
      classNames.add(classItem['name'] ?? classItem['id']);
    }
    
    setState(() {
      _availableClasses = classes;
      _availableClassNames = classNames;
      _selectedClass = "No class"; // Reset selection when major changes
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
  }
  
  // Submit the form
  Future<void> _submitForm() async {
    // Basic validation
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
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Prepare the product data
      Map<String, dynamic> productData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': int.parse(_priceController.text.trim()),
        'sellerID': _firebaseDAO.getCurrentUserId(),
        'status': 'Available', // Always set to Available as default
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'labels': _labels,
      };
      
      // Add image URL if provided
      if (_imageUrlController.text.trim().isNotEmpty) {
        productData['imageUrls'] = [_imageUrlController.text.trim()];
      }
      
      // Only add majorID if not "No major"
      if (_selectedMajor != "No major") {
        productData['majorID'] = _selectedMajor;
      }
      
      // Only add classID if not "No class"
      if (_selectedClass != "No class") {
        // Find the class ID that matches the selected class name
        String? classId;
        for (var classItem in _availableClasses) {
          if (classItem['name'] == _selectedClass || classItem['id'] == _selectedClass) {
            classId = classItem['id'];
            break;
          }
        }
        
        if (classId != null) {
          productData['classID'] = classId;
        }
      }
      //Actualizar los label counters del producto
      _firebaseDAO.updateProductPlacementMetrics(_labels);

      // Create the product
      final productId = await _firebaseDAO.createProduct(productData);
      
      if (productId != null) {
        _showSuccessAlert('Product uploaded successfully!');
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
      child: _isLoading ? 
        const Center(child: CupertinoActivityIndicator()) : 
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Image URL
                const Text('Image URL', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _imageUrlController,
                  placeholder: 'Enter URL to product image',
                  padding: const EdgeInsets.all(12),
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
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          color: CupertinoColors.systemBackground,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  CupertinoButton(
                                    child: const Text('Cancel'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  CupertinoButton(
                                    child: const Text('Done'),
                                    onPressed: () {
                                      // Store the selected major temporarily
                                      final String selectedMajor = _tempSelectedMajor ?? _selectedMajor;
                                      
                                      // Update the state and fetch classes only when Done is pressed
                                      setState(() {
                                        _selectedMajor = selectedMajor;
                                      });
                                      
                                      // Fetch classes for the selected major
                                      _fetchClassesForMajor(selectedMajor);
                                      
                                      Navigator.pop(context);
                                    },
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
                                  onSelectedItemChanged: (int index) {
                                    // Only store the value temporarily without fetching or updating state
                                    _tempSelectedMajor = _availableMajors[index];
                                  },
                                  children: _availableMajors.map((String major) => 
                                    Center(child: Text(major))
                                  ).toList(),
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
                
                // Class selection - only visible when a major is selected
                if (_selectedMajor != "No major") ...[
                  const Text('Class', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _isClassLoading ? 
                    const Center(child: CupertinoActivityIndicator()) :
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
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            color: CupertinoColors.systemBackground,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    CupertinoButton(
                                      child: const Text('Cancel'),
                                      onPressed: () => Navigator.pop(context),
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
                                    onSelectedItemChanged: (int index) {
                                      setState(() {
                                        _selectedClass = _availableClassNames[index];
                                      });
                                    },
                                    children: _availableClassNames.map((String className) => 
                                      Center(child: Text(className))
                                    ).toList(),
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
                
                // Labels selection
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _availableLabels.map((label) {
                    final isSelected = _labels.contains(label);
                    return GestureDetector(
                      onTap: () => _toggleLabel(label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryBlue : CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryBlue : CupertinoColors.systemGrey4,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? CupertinoColors.white : CupertinoColors.black,
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