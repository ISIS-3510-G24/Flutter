import 'dart:io';
import 'package:unimarket/services/image_cache_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/widgets/popups/not_implemented.dart';
import 'package:unimarket/theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final UserService _userService = UserService();
  UserModel? _userProfile;
  final ImageCacheService _imageCacheService = ImageCacheService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _trackScreenView();
    _loadUserProfile();
    _trackPerformance();
  }

  // 📊 Registrar que el usuario visitó esta pantalla en Firebase Analytics
  void _trackScreenView() {
    analytics.setCurrentScreen(screenName: "ProfileScreen");
  }

  // 🚨 Método para forzar un crash en Firebase Crashlytics
  void _forceCrash() {
    FirebaseCrashlytics.instance.crash();
  }

  // ⚡ Medir el rendimiento de carga con Firebase Performance
  Future<void> _trackPerformance() async {
    final Trace trace = FirebasePerformance.instance.newTrace("profile_screen_load");
    await trace.start();

    // Simulación de carga
    await Future.delayed(Duration(seconds: 1));

    await trace.stop();
  }

  // Cargar perfil del usuario desde Firestore
Future<void> _loadUserProfile() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Set a timeout to prevent infinite loading
    Future.delayed(Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        print("ProfileScreen: Loading timeout reached");
        setState(() {
          _isLoading = false;
        });
      }
    });
    
    // First try to get the user from the service
    final profile = await _userService.getCurrentUserProfile();
    
    if (!mounted) return;
    
    if (profile != null) {
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
      
      // If we have a profile picture URL, cache it for offline use
      if (profile.photoURL != null && profile.photoURL!.isNotEmpty) {
        _imageCacheService.getImageFile(profile.photoURL!).then((file) {
          print("ProfileScreen: Profile picture cached: ${file?.path}");
        });
      }
      
      return;
    }
    
    // If we failed to get a profile, create a placeholder from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Create a basic profile from FirebaseAuth user
      setState(() {
        _userProfile = UserModel(
          id: user.uid,
          displayName: user.displayName ?? "User",
          email: user.email ?? "user@example.com",
          photoURL: user.photoURL,
        );
        _isLoading = false;
      });
      
      // If we have a photo URL, cache it
      if (user.photoURL != null && user.photoURL!.isNotEmpty) {
        _imageCacheService.getImageFile(user.photoURL!);
      }
      
      return;
    }
    
    setState(() {
      _isLoading = false;
    });
  } catch (e) {
    print("ProfileScreen: Error loading user profile: $e");
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}



Future<void> _pickProfileImage() async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 800, // Optimizar tamaño de imagen
    maxHeight: 800,
    imageQuality: 85, // Buena calidad sin ser demasiado grande
  );
  
  if (pickedFile != null) {
    File imageFile = File(pickedFile.path);
    
    // Mostrar indicador de carga
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );
    
    try {
      final downloadUrl = await _userService.uploadProfilePicture(imageFile);
      
      // Descartar indicador de carga
      Navigator.of(context, rootNavigator: true).pop();
      
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
        
        // Guardar la imagen en caché inmediatamente
        await _imageCacheService.getImageFile(downloadUrl);
      }
    } catch (e) {
      // Descartar indicador de carga
      Navigator.of(context, rootNavigator: true).pop();
      
      // Mostrar error
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text("Error"),
          content: Text("Error al subir la imagen: $e"),
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
}

Widget _buildProfileImage(User? user) {
  // URL de la foto de perfil, ya sea del UserModel o del Firebase User
  final String? photoUrl = _userProfile?.photoURL ?? user?.photoURL;
  
  if (photoUrl == null || photoUrl.isEmpty) {
    // Sin foto de perfil, usar imagen de placeholder
    return Image.asset(
      "assets/images/Avatar.png",
      fit: BoxFit.cover,
      width: 100,
      height: 100,
    );
  }
  
  // Usar el servicio de caché para cargar la imagen
  return _imageCacheService.getOptimizedImageWidget(
    photoUrl,
    width: 100,
    height: 100,
    fit: BoxFit.cover,
    circle: true,
    placeholder: Center(child: CupertinoActivityIndicator()),
    defaultAsset: "assets/images/Avatar.png",
  );
}
  

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Settings",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
                children: [
                  const SizedBox(height: 20),

                  Stack(
  alignment: Alignment.bottomRight,
  children: [
    CircleAvatar(
      radius: 50,
      backgroundColor: CupertinoColors.systemGrey5,
      child: ClipOval(
        child: _buildProfileImage(user),
      ),
    ),
    CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _pickProfileImage,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          CupertinoIcons.pencil,
          color: CupertinoColors.white,
          size: 16,
        ),
      ),
    ),
  ],
),

                  const SizedBox(height: 10),

                  // 🔹 Información del usuario (nombre y username)
                  Text(
                    _userProfile?.displayName ?? user?.displayName ?? "User",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.black,
                    ),
                  ),
                  Text(
                    "@${_userProfile?.email.split('@').first ?? user?.email?.split('@').first ?? 'user'}",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: CupertinoColors.black,
                    ),
                  ),

                  // 🔹 Bio del usuario (si existe)
                  if (_userProfile?.bio != null && _userProfile!.bio!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Text(
                        _userProfile!.bio!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: CupertinoColors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // 🔹 Rating (si existe)
                  if (_userProfile?.ratingAverage != null && _userProfile!.reviewsCount != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.star_fill, color: CupertinoColors.systemYellow, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "${_userProfile!.ratingAverage!.toStringAsFixed(1)} (${_userProfile!.reviewsCount} reviews)",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: CupertinoColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 🔹 Lista de opciones
                  Expanded(
                    child: ListView(
                      children: [
                        _buildSettingItem(context, "Wishlist", route: '/wishlist'),
                        _buildSettingItem(context, "Edit Profile", route: '/edit-profile'),
                        _buildSettingItem(context, "Validate a product delivery (Seller)", route: '/genQR'),
                        _buildSettingItem(context, "Receive and validate a product (Buyer)", route: '/BLEscan'),
                        _buildSettingItem(context, "Log Out", logout: true),

                        const SizedBox(height: 20),

                        // 🚨 Botón para forzar un crash (solo en desarrollo)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: CupertinoButton(
                            onPressed: _forceCrash,
                            color: AppColors.primaryBlue,
                            child: const Text("Force Crash", style: TextStyle(color: CupertinoColors.white)),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ⚡ Botón para medir rendimiento (solo en desarrollo)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: CupertinoButton(
                            onPressed: _trackPerformance,
                            color: AppColors.primaryBlue,
                            child: const Text("Track Performance", style: TextStyle(color: CupertinoColors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // 🔹 Método para construir cada ítem de la lista de configuraciones
  Widget _buildSettingItem(BuildContext context, String title, {bool logout = false, String? route}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        if (logout) {
          await FirebaseAuth.instance.signOut();
          Navigator.pushReplacementNamed(context, '/mainlogin');
        } else if (route != null) {
          Navigator.pushNamed(context, route);
        } else {
          Navigator.push(context, CupertinoPageRoute(builder: (context) => const NotImplementedScreen()));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 16, color: AppColors.primaryBlue),
            ),
            const Icon(CupertinoIcons.right_chevron, color: CupertinoColors.systemGrey, size: 18),
          ],
        ),
      ),
    );
  }
}