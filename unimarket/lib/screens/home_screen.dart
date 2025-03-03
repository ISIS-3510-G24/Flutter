import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

// SCREENS
import 'package:unimarket/screens/tabs/explore_screen.dart';
import 'package:unimarket/screens/tabs/profile_screen.dart';
import 'package:unimarket/screens/tabs/chat_screen.dart';
import 'package:unimarket/screens/tabs/find_offer_screen.dart';
import 'package:unimarket/screens/tabs/orders_screen.dart';
import 'package:unimarket/widgets/popups/not_implemented.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 2; // Comienza en Explore

  // Lista de pantallas para mostrar
  final List<Widget> _screens = const [
    NotImplementedScreen(), // Orders
    NotImplementedScreen(), // Find & Offer
    ExploreScreen(),        // Explore
    NotImplementedScreen(), // Chat
    ProfileScreen(), // Profile - Cambiado temporalmente
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // Área de contenido principal - ocupa todo el espacio disponible
            Expanded(
              child: _screens[_selectedIndex],
            ),
            
            // Barra de navegación fija en la parte inferior
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                border: const Border(
                  top: BorderSide(color: CupertinoColors.systemGrey5, width: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildNavItem("assets/icons/Orders.svg", "Orders", 0),
                  _buildNavItem("assets/icons/FindAndOffer.svg", "Find & Offer", 1),
                  _buildNavItem("assets/icons/Explore.svg", "Explore", 2),
                  _buildNavItem("assets/icons/Chat.svg", "Chat", 3),
                  _buildNavItem("assets/icons/Profile.svg", "Profile", 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(String iconPath, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  isSelected ? const Color(0xFF66B7F0) : const Color(0xFFB0B3B8),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? CupertinoColors.black : const Color(0xFFB0B3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}