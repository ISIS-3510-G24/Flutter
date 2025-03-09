import 'package:flutter/cupertino.dart';
import 'package:unimarket/screens/main_login_screen.dart';
import 'package:unimarket/screens/splash_screen.dart';
import 'package:unimarket/screens/home_screen.dart';
import 'package:unimarket/screens/introduction_screen.dart';
import 'package:unimarket/screens/preferences_screen.dart'; 
import 'package:unimarket/screens/login_screen.dart'; 
import 'package:unimarket/screens/tabs/qr_scan.dart';
import 'package:unimarket/screens/tabs/qr_generate.dart';

//Para anadir pantalla nueva le agregan el import y ponen un case abajo.

class Routes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      
      case '/':
        return CupertinoPageRoute(builder: (_) => const SplashScreen());
      case '/intro': 
        return CupertinoPageRoute(builder: (_) => const IntroductionScreen());
      case '/home':
        return CupertinoPageRoute(builder: (_) => HomeScreen());
      case '/preferences':
        return CupertinoPageRoute(builder: (_) => const PreferencesScreen()); 
      case '/mainlogin':
        return CupertinoPageRoute(builder: (_) => const MainLogin());
      case '/login':
        return CupertinoPageRoute(builder: (_) => const LoginScreen());
      case '/genQR':
        return CupertinoPageRoute(builder: (_) => const QrGenerate());
      case '/scanQR':
        return CupertinoPageRoute(builder: (_) => const QrScan());
      default:
        return CupertinoPageRoute(
          builder: (_) => const CupertinoPageScaffold(
            child: Center(child: Text("Página no encontrada")),
          ),
        );
    }
  }
}
