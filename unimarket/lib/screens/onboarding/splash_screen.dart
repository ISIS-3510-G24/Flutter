import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacementNamed('/intro');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF93D2FF), Color(0xFFBCE9FF)],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _controller.value * 2 * 3.1416,
                      child: child,
                    );
                  },
                  child: SvgPicture.asset(
                    'assets/svgs/LogoArrows.svg',
                    width: 350,
                    height: 350,
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/svgs/LogoCircle.svg',
                      width: 210,
                      height: 210,
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
}
