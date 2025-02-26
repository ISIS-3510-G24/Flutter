import 'package:flutter/cupertino.dart';
import 'package:unimarket/screens/splash_screen.dart';
import 'package:unimarket/routes.dart';  

void main() {
  runApp(const UniMarketApp());
}

class UniMarketApp extends StatelessWidget {
  const UniMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',  
      onGenerateRoute: Routes.generateRoute, 
    );
  }
}
