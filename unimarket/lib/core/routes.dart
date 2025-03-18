import 'package:flutter/cupertino.dart';
import 'package:unimarket/screens/auth/main_login_screen.dart';
import 'package:unimarket/screens/onboarding/splash_screen.dart';
import 'package:unimarket/screens/home/home_screen.dart';
import 'package:unimarket/screens/onboarding/introduction_screen.dart';
import 'package:unimarket/screens/onboarding/preferences_screen.dart'; 
import 'package:unimarket/screens/auth/auth_validator.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';
import 'package:unimarket/screens/profile/edit_profile_screen.dart';
import 'package:unimarket/screens/profile/wishlist_screen.dart'; 
import 'package:unimarket/screens/qr/qr_scan.dart';
import 'package:unimarket/screens/qr/qr_generate.dart';

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
      case '/authval':
        return CupertinoPageRoute(builder: (_) => const AuthValidator());
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
