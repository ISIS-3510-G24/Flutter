import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class IntroductionScreen extends StatefulWidget {
  const IntroductionScreen({super.key});

  @override
  _IntroductionScreenState createState() => _IntroductionScreenState();
}

class _IntroductionScreenState extends State<IntroductionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      "image": "assets/images/PlainLogoWithBackground.png",
      "title": "Welcome to UniMarket",
      "description":
          "Post your items with a few taps, set your price, and connect with buyers instantly. Buy and sell the best school supplies with our app!",
    },
    {
      "image": "assets/images/Marketplace.jpg",
      "title": "Buy & Sell School Supplies with Ease",
      "description":
          "Find the supplies you need or sell what you no longer use. Whether you're looking for textbooks, calculators, or art materials, we've got you covered!"
    },
    {
      "image": "assets/images/Notebooks.png",
      "title": "Turn Your Unused Supplies into Cash",
      "description":
          "Post your items with a few taps, set your price, and connect with buyers instantly. Quick & easy listing process.",
      "credit": "Image by gstudioimagen on Freepik"
    }
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/mainlogin'); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/mainlogin'); // Saltar intro
          },
          child: Text(
            'Skip Intro',
            style: GoogleFonts.inter(
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
                flex: 5, // La imagen ocupa la mitad superior de la pantalla
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Se asegura que todas las imágenes tengan la misma altura
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5, // Ocupa 50% de la pantalla
                          width: double.infinity, // Ocupa todo el ancho disponible
                          child: Image.asset(
                            page["image"]!,
                            fit: BoxFit.cover, // Ajusta la imagen sin distorsionarla
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _pages.length,
                            (i) => CircleIndicator(isActive: i == _currentPage),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                page["title"]!,
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                page["description"]!,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                              if (page.containsKey("credit")) ...[
                                const SizedBox(height: 10),
                                Text(
                                  page["credit"]!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: CupertinoColors.systemGrey2,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),


            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: const Color(0xFF66B7F0),
                  borderRadius: BorderRadius.zero,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  onPressed: _nextPage, // Mueve onPressed arriba
                  child: Text(
                    _currentPage < _pages.length - 1 ? "Next" : "Get Started",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Indicadores de página
class CircleIndicator extends StatelessWidget {
  final bool isActive;
  const CircleIndicator({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? const Color(0xFF66B7F0) : CupertinoColors.systemGrey3,
      ),
    );
  }
}
