import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unimarket/services/find_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/data/database_helper.dart';

class CreateOfferScreen extends StatefulWidget {
  final String findId;

  const CreateOfferScreen({Key? key, required this.findId}) : super(key: key);

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  final FindService _findService = FindService();
  final ConnectivityService _connectivityService = ConnectivityService(); // Singleton instance
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;

  late StreamSubscription<bool> _connectivitySubscription;
  late StreamSubscription<bool> _checkingSubscription;

  bool _isConnected = true; // Estado de conectividad
  bool _isCheckingConnectivity = false;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen((bool isConnected) {
      setState(() {
        _isConnected = isConnected;
      });

      if (isConnected) {
        print("Internet connection restored. Syncing local offers...");
        _syncLocalOffers();
      } else {
        print("You are offline. Some features may not work.");
      }
    });

    // Configura la suscripción para el checkingStream
    _checkingSubscription = _connectivityService.checkingStream.listen((bool isChecking) {
      setState(() {
        _isCheckingConnectivity = isChecking;
      });
    });
  }

  Future<void> _syncLocalOffers() async {
    final hasInternet = await _connectivityService.checkConnectivity();
    if (!hasInternet) {
      print("No internet connection. Skipping sync.");
      return;
    }

    final dbHelper = DatabaseHelper();
    final localOffers = await dbHelper.getLocalOffers();

    if (localOffers.isNotEmpty) {
      for (var offer in localOffers) {
        try {
          print("Syncing offer: $offer");
          await _findService.createOffer(
            findId: offer['findId'],
            userName: offer['userId'].toString(),
            description: offer['description'],
            image: offer['image'],
            price: offer['price'],
          );

          // Eliminar la oferta local después de sincronizarla
          await dbHelper.deleteLocalOffer(offer['id']);
          print("Offer synced and removed locally: ${offer['id']}");
        } catch (e) {
          print("Error syncing offer: ${offer['id']}, Error: $e");
        }
      }
    }
  }

  void _handleRetryPressed() async {
    // Forzar una verificación de conectividad
    bool hasInternet = await _connectivityService.checkConnectivity();
    setState(() {
      _isConnected = hasInternet;
    });
  }

  @override
void dispose() {
  _connectivitySubscription.cancel();
  _checkingSubscription?.cancel(); // Verifica si está inicializado antes de cancelarlo
  super.dispose();
}

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _createOffer() async {
    if (_descriptionController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      print("Description, price, and username are required.");
      return;
    }

    setState(() {
      _isUploading = true;
    });

    if (_isConnected) {
      print("Attempting to create offer online...");
      String? imageUrl;

      if (_selectedImage != null) {
        print("Uploading image...");
        imageUrl = await _findService.uploadOfferImage(
          _selectedImage!.path,
          widget.findId,
        );
        print("Image uploaded: $imageUrl");
      }

      await _findService.createOffer(
        findId: widget.findId,
        userName: _usernameController.text,
        description: _descriptionController.text,
        image: imageUrl,
        price: int.parse(_priceController.text),
      );

      print("Offer created successfully online!");
      Navigator.pop(context);
    } else {
      print("No internet connection. Saving offer locally...");
      final dbHelper = DatabaseHelper();
      await dbHelper.insertOffer({
        'findId': widget.findId,
        'userId': 1, // Assuming a default user ID for now
        'description': _descriptionController.text,
        'price': int.parse(_priceController.text),
        'image': _selectedImage?.path,
      });

      print("Offer saved locally!");
      showDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("No Internet"),
          content: const Text("Offer saved locally. It will be uploaded when online."),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }

    setState(() {
      _isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Create Offer"),
        previousPageTitle: "Back",
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                if (!_isConnected || _isCheckingConnectivity)
                  Container(
                    width: double.infinity,
                    color: CupertinoColors.systemYellow.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        _isCheckingConnectivity
                            ? const CupertinoActivityIndicator(radius: 8)
                            : const Icon(
                                CupertinoIcons.exclamationmark_triangle,
                                size: 16,
                                color: CupertinoColors.systemYellow,
                              ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isCheckingConnectivity
                                ? "Checking internet connection..."
                                : "You are offline. Some features may not work.",
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                        if (!_isCheckingConnectivity)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            child: const Text(
                              "Retry",
                              style: TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.activeBlue,
                              ),
                            ),
                            onPressed: _handleRetryPressed,
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CupertinoTextField(
                          controller: _usernameController,
                          placeholder: "Username",
                        ),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          controller: _descriptionController,
                          placeholder: "Description",
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          controller: _priceController,
                          placeholder: "Price",
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: CupertinoColors.systemGrey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _selectedImage != null
                                ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  )
                                : const Center(
                                    child: Text(
                                      "Tap to select an image",
                                      style: TextStyle(color: CupertinoColors.systemGrey),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoButton.filled(
                          onPressed: _isUploading ? null : _createOffer,
                          child: _isUploading
                              ? const CupertinoActivityIndicator()
                              : const Text("Create Offer"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}