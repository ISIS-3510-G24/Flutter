import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final UserService _userService = UserService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  UserModel? _userProfile;

  @override
  void initState() {
    super.initState();
    _trackScreenView();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // 📊 Track screen view
  void _trackScreenView() {
    analytics.setCurrentScreen(screenName: "EditProfileScreen");
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });
    
    final profile = await _userService.getCurrentUserProfile();
    setState(() {
      _userProfile = profile;
      if (profile != null) {
        _nameController.text = profile.displayName;
        _bioController.text = profile.bio ?? '';
      }
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (_userProfile == null) return;
    
    setState(() {
      _isSaving = true;
    });

    // Preparar los datos a actualizar
    final userData = {
      'displayName': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
    };

    // Actualizar el perfil
    final success = await _userService.updateUserProfile(userData);
    
    setState(() {
      _isSaving = false;
    });

    if (success) {
      // Mostrar mensaje de éxito
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("Success"),
          content: const Text("Your profile has been updated successfully."),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Volver a la pantalla anterior
              },
            ),
          ],
        ),
      );
    } else {
      // Mostrar mensaje de error
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("Error"),
          content: const Text("Failed to update your profile. Please try again."),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(context),
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
          "Edit Profile",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        trailing: _isSaving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(
                  "Save",
                  style: GoogleFonts.inter(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _saveProfile,
              ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Avatar con opción para cambiar (comentado por ahora)
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: CupertinoColors.systemGrey5,
                          child: _userProfile?.photoURL != null
                              ? ClipOval(
                                  child: Image.network(
                                    _userProfile!.photoURL!,
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CupertinoActivityIndicator(),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        "assets/images/Avatar.png",
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                )
                              : Image.asset(
                                  "assets/images/Avatar.png",
                                  fit: BoxFit.cover,
                                ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.camera,
                              color: CupertinoColors.white,
                              size: 16,
                            ),
                          ),
                          onPressed: () {
                            // NOTA: Funcionalidad comentada ya que Firebase Storage no está configurado
                            showCupertinoDialog(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: const Text("Feature Not Available"),
                                content: const Text("Image upload functionality will be available soon."),
                                actions: [
                                  CupertinoDialogAction(
                                    child: const Text("OK"),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            );
                            
                            // Código para cambiar la imagen (cuando Firebase Storage esté configurado)
                            /* 
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            
                            if (pickedFile != null) {
                              File imageFile = File(pickedFile.path);
                              
                              showCupertinoDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CupertinoActivityIndicator()),
                              );
                              
                              try {
                                final downloadUrl = await _userService.uploadProfilePicture(imageFile);
                                Navigator.pop(context);
                                
                                if (downloadUrl != null) {
                                  setState(() {
                                    if (_userProfile != null) {
                                      _userProfile = UserModel(
                                        id: _userProfile!.id,
                                        displayName: _userProfile!.displayName,
                                        email: _userProfile!.email,
                                        photoURL: downloadUrl,
                                        bio: _userProfile!.bio,
                                        ratingAverage: _userProfile!.ratingAverage,
                                        reviewsCount: _userProfile!.reviewsCount,
                                        createdAt: _userProfile!.createdAt,
                                        updatedAt: _userProfile!.updatedAt,
                                      );
                                    }
                                  });
                                }
                              } catch (e) {
                                Navigator.pop(context);
                                showCupertinoDialog(
                                  context: context,
                                  builder: (context) => CupertinoAlertDialog(
                                    title: const Text("Error"),
                                    content: Text("Failed to upload image: $e"),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: const Text("OK"),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                            */
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Campo para el nombre
                  _buildFormSection(
                    title: "Display Name",
                    child: CupertinoTextField(
                      controller: _nameController,
                      placeholder: "Enter your name",
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Campo para la bio
                  _buildFormSection(
                    title: "Bio",
                    child: CupertinoTextField(
                      controller: _bioController,
                      placeholder: "Tell us about yourself",
                      padding: const EdgeInsets.all(12),
                      maxLines: 4,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Botón para guardar
                  CupertinoButton(
                    color: AppColors.primaryBlue,
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : Text(
                            "Save Changes",
                            style: GoogleFonts.inter(color: CupertinoColors.white),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFormSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.systemGrey,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}