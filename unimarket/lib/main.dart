import 'package:flutter/cupertino.dart';
import 'package:unimarket/firebase_options.dart';
import 'package:unimarket/routes.dart';  
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
