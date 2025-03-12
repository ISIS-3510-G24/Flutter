import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/widgets/popups/not_implemented.dart';
import 'package:unimarket/theme/app_colors.dart'; // Importa el archivo de colores

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  void initState() {
    super.initState();
    _trackScreenView();
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
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 🔹 Avatar con botón de edición
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: CupertinoColors.systemGrey5,
                  child: user?.photoURL != null
                      ? ClipOval(
                          child: Image.network(user!.photoURL!, fit: BoxFit.cover),
                        )
                      : Image.asset("assets/images/Avatar.png", fit: BoxFit.cover),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue, // Usa el azul oficial
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.pencil, color: CupertinoColors.white, size: 16),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(builder: (context) => const NotImplementedScreen()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 🔹 Nombre y usuario
            Text(
              user?.displayName ?? "User",
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: CupertinoColors.black),
            ),
            Text(
              "@${user?.email?.split('@').first ?? 'user'}",
              style: GoogleFonts.inter(fontSize: 14, color: CupertinoColors.black),
            ),

            const SizedBox(height: 20),

            // 🔹 Lista de opciones (usando Expanded)
            Expanded(
              child: ListView(
                children: [
                  _buildSettingItem(context, "Wishlist"),
                  _buildSettingItem(context, "Recent Purchases"),
                  _buildSettingItem(context, "Analytics"),
                  _buildSettingItem(context, "Notifications"),
                  _buildSettingItem(context, "Appearance"),
                  _buildSettingItem(context, "Language"),
                  _buildSettingItem(context, "Privacy & Security"),
                  _buildSettingItem(context, "Validate a product delivery (seller)", route: '/genQR'),
                  _buildSettingItem(context, "Receive and validate a product (buyer)", route: '/scanQR'),
                  _buildSettingItem(context, "Log Out", logout: true),

                  // Añadir espacio entre "Log Out" y los botones
                  const SizedBox(height: 20),

                  // 🚨 Botón para forzar un crash
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CupertinoButton(
                      onPressed: _forceCrash,
                      color: AppColors.primaryBlue, // Usa el azul oficial
                      child: Text("Force Crash", style: TextStyle(color: CupertinoColors.white)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ⚡ Botón para medir rendimiento
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CupertinoButton(
                      onPressed: _trackPerformance,
                      color: AppColors.primaryBlue, // Usa el azul oficial
                      child: Text("Track Performance", style: TextStyle(color: CupertinoColors.white)),
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

  // 🔹 Método para construir cada ítem de la lista
  Widget _buildSettingItem(BuildContext context, String title, {bool logout = false}) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        if (logout) {
          await FirebaseAuth.instance.signOut();
          Navigator.pushReplacementNamed(context, '/login');
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
