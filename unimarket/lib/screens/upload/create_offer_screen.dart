import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/services/find_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class CreateOfferScreen extends StatefulWidget {
  final String findId;

  const CreateOfferScreen({Key? key, required this.findId}) : super(key: key);

  @override
  _CreateOfferScreenState createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final FindService _findService = FindService();

  void _submitOffer() async {
    final userName = _userNameController.text;
    final description = _descriptionController.text;
    final image = _imageController.text;
    final price = double.tryParse(_priceController.text); // Cambiar a double

    if (userName.isEmpty || description.isEmpty || price == null) {
      // Mostrar un mensaje de error si los campos están vacíos
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text("Error"),
          content: const Text("Please fill in all required fields."),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await _findService.createOffer(
        findId: widget.findId,
        userName: userName,
        description: description,
        image: image,
        price: price.toInt(), // Convert double to int
      );

      // Navegar de regreso después de crear la oferta
      Navigator.pop(context);
    } catch (e) {
      print("Error creating offer: $e");
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text("Error"),
          content: const Text("Failed to create offer. Please try again later."),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "New Offer",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CupertinoTextField(
                  controller: _userNameController,
                  placeholder: "User Name",
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: _descriptionController,
                  placeholder: "Description",
                  padding: const EdgeInsets.all(16),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: _imageController,
                  placeholder: "Image URL (optional)",
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  controller: _priceController,
                  placeholder: "Price",
                  padding: const EdgeInsets.all(16),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 32),
                Center(
                  child: CupertinoButton(
                    onPressed: _submitOffer,
                    color: Color.fromARGB(255, 96, 201, 245), // Fondo azul claro
                    child: const Text(
                      "Submit",
                      style: TextStyle(color: CupertinoColors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}