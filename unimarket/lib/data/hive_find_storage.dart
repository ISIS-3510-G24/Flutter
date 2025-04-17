import 'package:hive_flutter/hive_flutter.dart';

class HiveFindStorage {
  // Nombre de la caja
  static const String _findBoxName = 'pendingFinds';

  static bool isInitialized = false;

  // Inicializar Hive para "finds"
  static Future<void> initialize() async {
    if (isInitialized) {
      print('HiveFindStorage: Already initialized');
      return;
    }

    try {
      print('HiveFindStorage: Initializing Hive...');
      if (!Hive.isBoxOpen(_findBoxName)) {
        await Hive.openBox(_findBoxName);
        print('HiveFindStorage: Opened $_findBoxName box');
      }
      isInitialized = true;
    } catch (e) {
      print('HiveFindStorage: Error initializing storage: $e');
      isInitialized = false;
      rethrow;
    }
  }

  // Guardar un "find" localmente
  static Future<void> saveFind(Map<String, dynamic> find) async {
    final box = await Hive.openBox('offline_finds');
    final key = DateTime.now().millisecondsSinceEpoch.toString(); // clave única
    await box.put(key, find);
  }
  // Obtener todos los "finds" guardados localmente
  // HiveFindStorage.dart
 static Future<Map<String, Map<String, dynamic>>> getAllFinds() async {
    final box = await Hive.openBox('offline_finds');
    return Map<String, Map<String, dynamic>>.from(box.toMap());
  }


  // Eliminar un "find" después de subirlo
  static Future<void> deleteFind(String key) async {
    final box = await Hive.openBox('offline_finds');
    await box.delete(key);
  }

  // Limpiar todos los "finds" locales
  static Future<void> clearAllFinds() async {
    try {
      final box = Hive.box(_findBoxName);
      await box.clear();
      print('HiveFindStorage: All finds cleared');
    } catch (e) {
      print('HiveFindStorage: Error clearing finds: $e');
    }
  }
}