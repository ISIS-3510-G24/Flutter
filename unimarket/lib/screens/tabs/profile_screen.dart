import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/widgets/popups/not_implemented.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                      color: const Color(0xFF66B7F0),
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
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              "@${user?.email?.split('@').first ?? 'user'}",
              style: GoogleFonts.inter(fontSize: 14, color: CupertinoColors.systemGrey),
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
                  _buildSettingItem(context, "Log Out", logout: true),
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
              style: GoogleFonts.inter(fontSize: 16),
            ),
            const Icon(CupertinoIcons.right_chevron, color: CupertinoColors.systemGrey, size: 18),
          ],
        ),
      ),
    );
  }
}
