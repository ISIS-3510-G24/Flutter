import 'package:flutter/cupertino.dart';
import 'package:unimarket/screens/splash_screen.dart';
import 'package:unimarket/screens/home_screen.dart';
import 'package:unimarket/screens/introduction_screen.dart'; // Importamos la nueva pantalla

class Routes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return CupertinoPageRoute(builder: (_) => const SplashScreen());
      case '/intro':  // asi se agregan las pantallas
        return CupertinoPageRoute(builder: (_) => const IntroductionScreen());
      case '/home':
        return CupertinoPageRoute(builder: (_) => const HomeScreen());
      default:
        return CupertinoPageRoute(
          builder: (_) => const CupertinoPageScaffold(
            child: Center(child: Text("Página no encontrada")),
          ),
        );
    }
  }
}
