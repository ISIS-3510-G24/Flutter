import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

class IntroductionScreen extends StatelessWidget {
  const IntroductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text(
            'Skip Intro',
            style: TextStyle(color: CupertinoColors.systemGrey),
          ),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home'); // Ir a Home
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SvgPicture.asset(
                  'assets/svgs/LogoCircle.svg', // Usa el SVG que ya funciona
                  fit: BoxFit.contain,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Indicadores de progreso
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleIndicator(isActive: true),
                CircleIndicator(isActive: false),
                CircleIndicator(isActive: false),
              ],
            ),
            const SizedBox(height: 20),

            // Título y descripción
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to UniMarket',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter', // Apply Inter font
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Post your items with a few taps, set your price, and connect with buyers instantly. '
                    'Buy and sell the best school supplies with our app! What are you waiting for!',
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                      fontFamily: 'Inter', // Apply Inter font
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón "Next" actualizado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity, // Ocupa todo el ancho disponible
                child: CupertinoButton(
                  color: const Color(0xFF66B7F0), // Color principal
                  borderRadius: BorderRadius.zero, // Sin bordes redondeados
                  padding: const EdgeInsets.symmetric(vertical: 15), // Altura del botón
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      fontSize: 18,
                      color: CupertinoColors.white,
                      fontFamily: 'Inter', // Apply Inter font
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home'); // Ir a Home
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// Widget para los indicadores de página
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
        color: isActive ? const Color(0xFF66B7F0) : CupertinoColors.systemGrey3, // Usa el color principal
      ),
    );
  }
}
