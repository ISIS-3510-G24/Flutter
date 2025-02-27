import 'package:flutter/cupertino.dart';
import 'package:unimarket/screens/splash_screen.dart';
import 'package:unimarket/screens/home_screen.dart';
import 'package:unimarket/screens/introduction_screen.dart';
import 'package:unimarket/screens/preferences_screen.dart'; 
//Para anadir pantalla nueva le agregan el import y ponen un case abajo.

class Routes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return CupertinoPageRoute(builder: (_) => const SplashScreen());
      case '/intro': 
        return CupertinoPageRoute(builder: (_) => const IntroductionScreen());
      case '/home':
        return CupertinoPageRoute(builder: (_) => const HomeScreen());
        case '/preferences':
        return CupertinoPageRoute(builder: (_) => const PreferencesScreen()); 
      default:
        return CupertinoPageRoute(
          builder: (_) => const CupertinoPageScaffold(
            child: Center(child: Text("Página no encontrada")),
          ),
        );
    }
  }
}
