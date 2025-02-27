import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/home_screen.dart';
import 'popups/not_implemented.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1; // Posición inicial en "Explore"

  final List<Widget> _screens = [
    NotImplementedScreen(), // Orders
    NotImplementedScreen(), // Find & Offer
    HomeScreen(),           // Explore
    NotImplementedScreen(), // Chat
    NotImplementedScreen(), // Profile
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          _screens[_selectedIndex], // Contenido principal
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                color: CupertinoColors.white,
                border: Border(top: BorderSide(color: CupertinoColors.systemGrey4, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem("assets/icons/Orders.svg", "Orders", 0),
                  _buildNavItem("assets/icons/FindAndOffer.svg", "Find & Offer", 1),
                  _buildNavItem("assets/icons/Explore.svg", "Explore", 2),
                  _buildNavItem("assets/icons/Chat.svg", "Chat", 3),
                  _buildNavItem("assets/icons/Profile.svg", "Profile", 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String iconPath, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              isSelected ? const Color(0xFF66B7F0) : const Color(0xFFD4D6DD),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? CupertinoColors.black : const Color(0xFFD4D6DD),
            ),
          ),
        ],
      ),
    );
  }
}
