import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unimarket/services/find_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/data/hive_find_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:unimarket/screens/find_and_offer_screens/audio_to_text_screen.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/data/firebase_dao.dart';

class ConfirmProductScreen extends StatefulWidget {
  final String postType; // "find" o "offer"

  const ConfirmProductScreen({Key? key, required this.postType}) : super(key: key);

  @override
  State<ConfirmProductScreen> createState() => _ConfirmProductScreenState();
}

class _ConfirmProductScreenState extends State<ConfirmProductScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();
  final FindService _findService = FindService();
  final ConnectivityService _connectivityService = ConnectivityService(); // Singleton instance

  List<String> _majors = [];
  String _selectedMajor = "";
  final List<String> _labels = [
    "Academics", "Accessories", "Art", "Decoration", "Design", "Education",
    "Electronics", "Engineering", "Entertainment", "Fashion", "Handcrafts",
    "Home", "Other", "Sports", "Technology", "Wellness"
  ];
  final List<String> _selectedLabels = [];

  late StreamSubscription<bool> _connectivitySubscription;
  late StreamSubscription<bool> _checkingSubscription;

  bool _isConnected = true; // Estado de conectividad
  bool _isCheckingConnectivity = false;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
    _loadMajors();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen((bool isConnected) {
      setState(() {
        _isConnected = isConnected;
      });

      if (isConnected && !_isSyncing) {
  print("Internet connection restored. Syncing offline finds...");
  _uploadOfflineFinds();
} else {
        print("You are offline. Some features may not work.");
      }
    });

    _checkingSubscription = _connectivityService.checkingStream.listen((bool isChecking) {
      setState(() {
        _isCheckingConnectivity = isChecking;
      });
    });
  }

 bool _isSyncing = false;

Future<void> _uploadOfflineFinds() async {
  if (_isSyncing) return; // Previene múltiples ejecuciones simultáneas
  _isSyncing = true;

  try {
    print("Starting offline finds sync...");
    final findsMap = await HiveFindStorage.getAllFinds();

    if (findsMap.isNotEmpty) {
      print("Found ${findsMap.length} offline finds to sync.");
      for (final entry in findsMap.entries) {
        final key = entry.key;
        final find = entry.value;

        try {
          // Verifica si el find ya existe en Firebase
          final exists = await _findService.findExists(find['title']);
          if (exists) {
            print("Find with title '${find['title']}' already exists in Firebase. Skipping upload.");
            await HiveFindStorage.deleteFind(key); // Elimina el find localmente
            continue;
          }

          print("Uploading find with key $key: $find");
          await _findService.createFind(
            title: find['title'],
            description: find['description'],
            image: find['image'],
            major: find['major'],
            labels: List<String>.from(find['labels']),
          );

          await HiveFindStorage.deleteFind(key);
          print('Find uploaded and removed from local storage');
        } catch (e) {
          print('Error uploading find with key $key: $e');
        }
      }
    } else {
      print("No offline finds to sync.");
    }
  } finally {
    _isSyncing = false;
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

  Future<void> _loadMajors() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('majors').get();
      final majors = snapshot.docs.map((doc) => doc.id).toList();
      setState(() {
        _majors = majors;
        if (_majors.isNotEmpty) {
          _selectedMajor = _majors.first;
        }
      });
    } catch (e) {
      debugPrint("Error loading majors: $e");
    }
  }

  Future<void> _submitFind() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final image = _imageController.text.trim();

    if (title.isEmpty || description.isEmpty || _selectedMajor.isEmpty || _selectedLabels.isEmpty) {
      _showErrorDialog("Please fill in all required fields.");
      return;
    }

    final findData = {
      'title': title,
      'description': description,
      'image': image,
      'major': _selectedMajor,
      'labels': _selectedLabels,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (!_isConnected) {
      await HiveFindStorage.saveFind(findData);
      _showInfoDialog("Saved Locally", "Your find has been saved locally and will be uploaded when you are online.");
      return;
    }

    try {
      await _findService.createFind(
        title: title,
        description: description,
        image: image,
        major: _selectedMajor,
        labels: _selectedLabels,
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error creating find: $e");
      _showErrorDialog("Failed to create find. Please try again later.");
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _openAudioToTextScreen() {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => AudioToTextScreen(
        onTextGenerated: (generatedText) {
          setState(() {
            _descriptionController.text = generatedText; // Actualiza solo la descripción
          });
        },
      ),
    ),
  );
}
 void _openAudioToTextScreenForTitle() {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => AudioToTextScreen(
        onTextGenerated: (generatedText) {
          setState(() {
            _titleController.text = generatedText; // Actualiza solo el título
          });
        },
      ),
    ),
  );
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
      child: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 16),
                    CupertinoTextField(
                      controller: _titleController,
                      placeholder: "Title",
                      padding: const EdgeInsets.all(16),
                      maxLines: 1,
                      suffix: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _openAudioToTextScreenForTitle, // Abre la pantalla de grabación para el título
                        child: const Icon(
                          CupertinoIcons.mic,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CupertinoTextField(
                      controller: _descriptionController,
                      placeholder: "Description",
                      padding: const EdgeInsets.all(16),
                      maxLines: 3,
                      suffix: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _openAudioToTextScreen, // Abre la pantalla de Audio to Text
                        child: const Icon(
                          CupertinoIcons.mic,
                          color: AppColors.primaryBlue,
                        ),
                      ),
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
                      color: Colors.transparent,
                      child: ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
                      child: CupertinoButton(
                        onPressed: _submitFind,
                        color: const Color.fromARGB(255, 96, 201, 245),
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
        ],
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
                children: _majors
                    .map((major) => Text(
                          major,
                          style: TextStyle(color: AppColors.primaryBlue),
                        ))
                    .toList(),
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