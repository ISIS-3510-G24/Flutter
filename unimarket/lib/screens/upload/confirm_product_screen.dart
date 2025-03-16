import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConfirmProductScreen extends StatefulWidget {
  final String? imageUrl;
  final String postType; 
  // "find" or "offer"

  const ConfirmProductScreen({
    Key? key,
    this.imageUrl,
    required this.postType,
  }) : super(key: key);

  @override
  State<ConfirmProductScreen> createState() => _ConfirmProductScreenState();
}

class _ConfirmProductScreenState extends State<ConfirmProductScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _characteristicsController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final ProductService _productService = ProductService();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _characteristicsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if it's a FIND or an OFFER
    final bool isFind = (widget.postType == "find");

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoNavigationBarBackButton(
          color: AppColors.primaryBlue,
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          isFind ? "Confirm Request" : "Confirm Offer",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Image preview (or placeholder)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemGrey4, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: widget.imageUrl != null
                        ? Image.network(
                            widget.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              CupertinoIcons.photo,
                              size: 60,
                            ),
                          )
                        : const Center(
                            child: Icon(CupertinoIcons.photo, size: 60),
                          ),
                  ),
                  const SizedBox(height: 8),

                  // Button to retake image
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Retake Image",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Text fields
                  _buildTextField(
                    _titleController,
                    isFind ? "Name of the request" : "Title of the product",
                    isFind ? "Enter request name" : "Enter product title",
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _descriptionController,
                    "Description",
                    "Enter description",
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _characteristicsController,
                    "Characteristics",
                    "Enter characteristics",
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _priceController,
                    "Price",
                    isFind ? "Desired price" : "Enter price",
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // "Confirm" button (text changes based on FIND or OFFER)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: CupertinoButton(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: _isLoading ? null : _onConfirm,
                      child: Text(
                        isFind ? "Confirm Request" : "Confirm Product",
                        style: GoogleFonts.inter(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Loading indicator
            if (_isLoading)
              Container(
                color: CupertinoColors.systemBackground.withOpacity(0.7),
                child: const Center(
                  child: CupertinoActivityIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Method to handle confirmation and upload to Firebase
  Future<void> _onConfirm() async {
    final bool isFind = (widget.postType == "find");
    
    // Validate inputs
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty || _priceController.text.isEmpty) {
      _showErrorDialog("Please fill in all required fields");
      return;
    }
    
    // Parse price
    double price;
    try {
      price = double.parse(_priceController.text);
    } catch (e) {
      _showErrorDialog("Please enter a valid price");
      return;
    }
    
    // Get current user ID
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showErrorDialog("You must be logged in to upload a product");
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Create a new product
      final product = ProductModel(
        classId: "2427", // Using a fixed class ID for now
        createdAt: DateTime.now(),
        description: _descriptionController.text,
        imageUrls: widget.imageUrl != null ? [widget.imageUrl!] : [],
        labels: ["Arts & Crafts"], // Using a fixed label for now
        majorID: "DISO", // Using a fixed major ID for now
        price: price,
        sellerID: currentUser.uid,
        status: "Available",
        title: _titleController.text,
        updatedAt: DateTime.now(),
      );
      
      // Upload product to Firestore
      final productId = await _productService.createProduct(product);
      
      if (productId != null) {
        // Show success dialog
        _showSuccessDialog();
      } else {
        _showErrorDialog("Failed to create product");
      }
    } catch (e) {
      _showErrorDialog("An error occurred: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Show success dialog
  void _showSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text("Success"),
          content: const Text("Your product has been uploaded successfully!"),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close screen
              },
            ),
          ],
        );
      },
    );
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text("Error"),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String placeholder, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          padding: const EdgeInsets.all(12),
          maxLines: maxLines,
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey4, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          style: GoogleFonts.inter(fontSize: 14),
        ),
      ],
    );
  }
}