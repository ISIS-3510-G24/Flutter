import 'package:flutter/cupertino.dart';
import 'package:unimarket/screens/auth/main_login_screen.dart';
import 'package:unimarket/screens/ble_scan/client_screen_scanner.dart';
import 'package:unimarket/screens/onboarding/splash_screen.dart';
import 'package:unimarket/screens/home/home_screen.dart';
import 'package:unimarket/screens/onboarding/introduction_screen.dart';
import 'package:unimarket/screens/onboarding/preferences_screen.dart'; 
import 'package:unimarket/screens/auth/login_screen.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';
import 'package:unimarket/screens/profile/edit_profile_screen.dart';
import 'package:unimarket/screens/profile/wishlist_screen.dart'; 

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
      case '/login':
        return CupertinoPageRoute(builder: (_) => const LoginScreen());
      case '/genQR':
        return CupertinoPageRoute(builder: (_) => const QrGenerate());
      case '/BLEscan':
        return CupertinoPageRoute(builder: (_) => const ClientScreenScan());
      case '/wishlist': 
      return CupertinoPageRoute(builder: (_) => const WishlistScreen());
      case '/edit-profile':
        return CupertinoPageRoute(builder: (_) => const EditProfileScreen());
      default:
        return CupertinoPageRoute(
          builder: (_) => const CupertinoPageScaffold(
            child: Center(child: Text("Página no encontrada")),
          ),
        );
    }
  }
}
