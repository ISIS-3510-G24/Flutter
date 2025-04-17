import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:unimarket/core/firebase_options.dart';
import 'package:unimarket/core/routes.dart';  
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:unimarket/data/hive_chat_storage.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/data/hive_find_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

 
  await HiveChatStorage.initialize();

  FirebaseFirestore.instance.settings = 
    Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);

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
      title: 'UniMarket',
      theme: const CupertinoThemeData(
        primaryColor: AppColors.primaryBlue,
        brightness: Brightness.light,
      ),
      initialRoute: '/',  
      onGenerateRoute: Routes.generateRoute, 
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
      ],
    );
  }
}
