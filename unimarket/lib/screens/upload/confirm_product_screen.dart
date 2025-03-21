import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FindService _findService = FindService();

  List<String> _majors = [];
  String _selectedMajor = "";
  final List<String> _labels = [
    "Academics", "Accessories", "Art", "Decoration", "Design", "Education", 
    "Electronics", "Engineering", "Entertainment", "Fashion", "Handcrafts", 
    "Home", "Other", "Sports", "Technology", "Wellness"
  ];
  final List<String> _selectedLabels = [];

  @override
  void initState() {
    super.initState();
    _loadMajors();
  }

  Future<void> _loadMajors() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('majors').get();
      final majors = snapshot.docs.map((doc) => doc.id).toList();
      setState(() {
        _majors = majors;
        if (_majors.isNotEmpty) {
          _selectedMajor = _majors[0];
        }
      });
    } catch (e) {
      print("Error loading majors: $e");
    }
  }

  void _submitFind() async {
    final title = _titleController.text;
    final description = _descriptionController.text;
    final image = _imageController.text;

    if (title.isEmpty || description.isEmpty || _selectedMajor.isEmpty || _selectedLabels.isEmpty) {
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
        major: _selectedMajor,
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
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
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
                Text(
                  "Select Major",
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showMajorPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedMajor.isEmpty ? "Select Major" : _selectedMajor,
                          style: GoogleFonts.inter(fontSize: 16, color: AppColors.primaryBlue),
                        ),
                        const Icon(CupertinoIcons.chevron_down, color: AppColors.primaryBlue),
                      ],
                    ),
                  ),
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
                        activeColor: AppColors.primaryBlue,
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

  void _showMajorPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 250,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedMajor = _majors[index];
                  });
                },
                children: _majors.map((major) => Text(major, style: TextStyle(color: AppColors.primaryBlue))).toList(),
              ),
            ),
            CupertinoButton(
              child: const Text("Done"),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}