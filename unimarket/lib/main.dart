import 'dart:ui';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:unimarket/app_initializer.dart';
import 'package:unimarket/core/firebase_options.dart';
import 'package:unimarket/core/routes.dart';  
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:unimarket/data/hive_chat_storage.dart';
import 'package:unimarket/data/sqlite_user_dao.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/services/image_cache_service.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/data/hive_find_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:unimarket/services/order_analysis_service.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase primero (crítico)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Main: Firebase initialized successfully');
  } catch (e) {
    print('Main: Error initializing Firebase: $e');
    // Firebase es crítico, pero continuemos para ver qué pasa
  }
  
  // Usar el inicializador para el resto de servicios
  try {
    await AppInitializer.initialize();
  } catch (e) {
    print('Main: Error during app initialization: $e');
    // Continuar a pesar del error para al menos mostrar UI básica
  }
  
  // Inicializar FirebaseAppCheck
  try {
    if (kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('12345678'),
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        appleProvider: AppleProvider.appAttest,
      );
    }
    print('Main: FirebaseAppCheck activated');
  } catch (e) {
    print('Main: Error activating FirebaseAppCheck: $e');
  }
  
  // Configurar Firestore
  try {
    FirebaseFirestore.instance.settings = 
      Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
    print('Main: Firestore configured successfully');
  } catch (e) {
    print('Main: Error configuring Firestore: $e');
  }
  
  // Configurar Crashlytics
  try {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    print('Main: Crashlytics configured successfully');
  } catch (e) {
    print('Main: Error configuring Crashlytics: $e');
  }
  
  // Iniciar la app incluso si hay errores de inicialización
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
