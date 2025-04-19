import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unimarket/services/find_service.dart';

class CreateOfferScreen extends StatefulWidget {
  final String findId;

  const CreateOfferScreen({Key? key, required this.findId}) : super(key: key);

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  final FindService _findService = FindService();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController(); // Campo para el username
  File? _selectedImage; // Imagen seleccionada
  bool _isUploading = false;

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

    String? imageUrl;

    // Subir la imagen si se seleccionó una
    if (_selectedImage != null) {
      imageUrl = await _findService.uploadOfferImage(
        _selectedImage!.path,
        widget.findId,
      );
    }

    // Crear la oferta
    await _findService.createOffer(
      findId: widget.findId,
      userName: _usernameController.text, // Usar el username ingresado
      description: _descriptionController.text,
      image: imageUrl,
      price: int.parse(_priceController.text),
    );

    setState(() {
      _isUploading = false;
    });

    print("Offer created successfully!");
    Navigator.pop(context); // Regresar a la pantalla anterior
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Create Offer"),
        previousPageTitle: "Back",
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo de username
              CupertinoTextField(
                controller: _usernameController,
                placeholder: "Username",
              ),
              const SizedBox(height: 16),
              // Campo de descripción
              CupertinoTextField(
                controller: _descriptionController,
                placeholder: "Description",
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Campo de precio
              CupertinoTextField(
                controller: _priceController,
                placeholder: "Price",
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // Botón para seleccionar imagen
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
              // Botón para crear oferta
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
    );
  }
}