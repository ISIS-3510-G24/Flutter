// En un archivo nuevo: lib/core/app_initializer.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:unimarket/data/hive_chat_storage.dart';
import 'package:unimarket/data/hive_find_storage.dart';
import 'package:unimarket/data/sqlite_user_dao.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/services/image_cache_service.dart';
import 'package:unimarket/services/offline_queue_service.dart';
import 'package:unimarket/services/user_service.dart';

class AppInitializer {
  static Future<void> initialize() async {
    print('AppInitializer: Starting initialization sequence');
    
    // Inicializar Hive primero (es una dependencia de otros servicios)
    try {
      print('AppInitializer: Initializing Hive...');
      await Hive.initFlutter();
      print('AppInitializer: Hive initialized successfully');
    } catch (e) {
      print('AppInitializer: Error initializing Hive: $e');
      // Continuar a pesar del error
    }
    
    // Inicializar HiveFindStorage con timeout
    try {
      print('AppInitializer: Initializing HiveFindStorage...');
      await _withTimeout(
        HiveFindStorage.initialize(),
        const Duration(seconds: 5),
        'HiveFindStorage initialization'
      );
      print('AppInitializer: HiveFindStorage initialized successfully');
    } catch (e) {
      print('AppInitializer: Error initializing HiveFindStorage: $e');
      // Continuar a pesar del error
    }
    
    // Inicializar SQLiteUserDAO con timeout
    final sqliteUserDAO = SQLiteUserDAO();
    try {
      print('AppInitializer: Initializing SQLiteUserDAO...');
      await _withTimeout(
        sqliteUserDAO.initialize(),
        const Duration(seconds: 5),
        'SQLiteUserDAO initialization'
      );
      print('AppInitializer: SQLiteUserDAO initialized successfully');
    } catch (e) {
      print('AppInitializer: Error initializing SQLiteUserDAO: $e');
      // Continuar a pesar del error
    }
    
    // Inicializar HiveChatStorage con timeout
    try {
      print('AppInitializer: Initializing HiveChatStorage...');
      await _withTimeout(
        HiveChatStorage.initialize(),
        const Duration(seconds: 5),
        'HiveChatStorage initialization'
      );
      print('AppInitializer: HiveChatStorage initialized successfully');
    } catch (e) {
      print('AppInitializer: Error initializing HiveChatStorage: $e');
      // Continuar a pesar del error
    }
    
    // Inicializar ImageCacheService con timeout
    final imageCacheService = ImageCacheService();
    try {
      print('AppInitializer: Initializing ImageCacheService...');
      await _withTimeout(
        imageCacheService.database, 
        const Duration(seconds: 5),
        'ImageCacheService initialization'
      );
      print('AppInitializer: ImageCacheService initialized successfully');
    } catch (e) {
      print('AppInitializer: Error initializing ImageCacheService: $e');
      // Continuar a pesar del error
    }
    
    // Inicializar UserService con timeout (último porque depende de los anteriores)
    final userService = UserService();
    try {
      print('AppInitializer: Initializing UserService...');
      await _withTimeout(
        userService.initialize(),
        const Duration(seconds: 5),
        'UserService initialization'
      );
      print('AppInitializer: UserService initialized successfully');
    } catch (e) {
      print('AppInitializer: Error initializing UserService: $e');
      // Continuar a pesar del error
    }
    
    // Comprobar conectividad y sincronizar usuario actual
    try {

      await OfflineQueueService().initialize();

      print('AppInitializer: Checking connectivity...');
      final connectivityService = ConnectivityService();
      final isOnline = await _withTimeout(
        connectivityService.checkConnectivity(),
        const Duration(seconds: 3),
        'Connectivity check'
      );
      
      if (isOnline) {
        print('AppInitializer: Online, synchronizing current user...');
        await _withTimeout(
          userService.syncCurrentUser(),
          const Duration(seconds: 5),
          'User synchronization'
        );
        print('AppInitializer: User synchronized successfully');
      } else {
        print('AppInitializer: Offline, using cached user data');
      }
    } catch (e) {
      print('AppInitializer: Error during connectivity check or user sync: $e');
    }
    
    print('AppInitializer: Initialization sequence completed');
  }
  
  // Método helper para añadir timeout a cualquier operación
  static Future<T> _withTimeout<T>(Future<T> operation, Duration timeout, String operationName) async {
    try {
      return await operation.timeout(timeout, onTimeout: () {
        throw TimeoutException('Timeout during $operationName');
      });
    } catch (e) {
      print('AppInitializer: Timeout or error in $operationName: $e');
      rethrow;
    }
  }
}