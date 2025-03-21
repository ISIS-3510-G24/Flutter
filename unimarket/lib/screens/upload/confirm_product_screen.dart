import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/services/find_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class ConfirmProductScreen extends StatefulWidget {
  final String postType; // "find" o "offer"

  const ConfirmProductScreen({Key? key, required this.postType}) : super(key: key);

  @override
  _ConfirmProductScreenState createState() => _ConfirmProductScreenState();
}

class _ConfirmProductScreenState extends State<ConfirmProductScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();
  final FindService _findService = FindService();

  final List<String> _labels = [
    "Academics", "Accessories", "Art", "Decoration", "Design", "Education", 
    "Electronics", "Engineering", "Entertainment", "Fashion", "Handcrafts", 
    "Home", "Other", "Sports", "Technology", "Wellness"
  ];
  final List<String> _selectedLabels = [];

  void _submitFind() async {
    final title = _titleController.text;
    final description = _descriptionController.text;
    final image = _imageController.text;
    final major = _majorController.text;

    if (title.isEmpty || description.isEmpty || major.isEmpty || _selectedLabels.isEmpty) {
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
      await _findService.createFind(
        title: title,
        description: description,
        image: image,
        major: major,
        labels: _selectedLabels, // Use the selected labels
      );

      // Navegar de regreso después de crear el find
      Navigator.pop(context);
    } catch (e) {
      print("Error creating find: $e");
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text("Error"),
          content: const Text("Failed to create find. Please try again later."),
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
          "New Find",
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
                  controller: _titleController,
                  placeholder: "Title",
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
                  controller: _majorController,
                  placeholder: "Major",
                  padding: const EdgeInsets.all(16),
                ),
                const SizedBox(height: 16),
                Text(
                  "Select Labels",
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Material(
                  child: ListView(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: _labels.map((label) {
                      return CheckboxListTile(
                        title: Text(label),
                        value: _selectedLabels.contains(label),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedLabels.add(label);
                            } else {
                              _selectedLabels.remove(label);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: CupertinoButton.filled(
                    onPressed: _submitFind,
                    child: const Text("Submit"),
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