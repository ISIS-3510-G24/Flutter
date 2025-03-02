import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:unimarket/firebase_options.dart';
import 'package:unimarket/routes.dart';  
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
   PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
    };

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
