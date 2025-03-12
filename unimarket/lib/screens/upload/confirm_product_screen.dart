import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';

class ConfirmProductScreen extends StatefulWidget {
  final String? imageUrl;
  final String postType; 
  // Por ejemplo: "find" o "offer"

  const ConfirmProductScreen({
    Key? key,
    this.imageUrl,
    required this.postType,
  }) : super(key: key);

  @override
  State<ConfirmProductScreen> createState() => _ConfirmProductScreenState();
}

class _ConfirmProductScreenState extends State<ConfirmProductScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _characteristicsController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _characteristicsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Para ver si es un FIND o un OFFER
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Imagen previa (o placeholder)
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

              // Botón para retomar la imagen
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  // Reabrir cámara o galería, si quisieras
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

              // Campos de texto
              _buildTextField(
                _nameController,
                isFind ? "Name of the request" : "Name of the product",
                isFind ? "Enter request name" : "Enter product name",
              ),
              const SizedBox(height: 8),
              _buildTextField(
                _descriptionController,
                "Description",
                "Enter description",
              ),
              const SizedBox(height: 8),
              _buildTextField(
                _characteristicsController,
                "Characteristics",
                "Enter characteristics",
              ),
              const SizedBox(height: 8),
              // En "find", el precio podría no ser obligatorio, pero lo dejamos igual
              _buildTextField(
                _priceController,
                "Price",
                isFind ? "Desired price" : "Enter price",
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Botón “Confirm” (cambia texto según sea FIND u OFFER)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: CupertinoButton(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: _onConfirm,
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
      ),
    );
  }

  // Al confirmar, se podría subir a Firebase a la colección de finds u offers
  void _onConfirm() {
    final bool isFind = (widget.postType == "find");

    // Ejemplo de pseudo-lógica:
    // if (isFind) {
    //    FirebaseFirestore.instance.collection("finds").add({
    //       "name": _nameController.text,
    //       "description": _descriptionController.text,
    //       ...
    //    });
    // } else {
    //    FirebaseFirestore.instance.collection("offers").add({
    //       ...
    //    });
    // }

    debugPrint("postType: ${widget.postType}");
    debugPrint("Nombre: ${_nameController.text}");
    debugPrint("Descripcion: ${_descriptionController.text}");
    debugPrint("Caracteristicas: ${_characteristicsController.text}");
    debugPrint("Precio: ${_priceController.text}");

    // Cerrar la pantalla después de "confirmar"
    Navigator.pop(context);
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String placeholder, {
    TextInputType keyboardType = TextInputType.text,
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
