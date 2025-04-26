import 'package:hive_flutter/hive_flutter.dart';

class HiveFindStorage {
  // Nombres de las cajas
  static const String _findBoxName = 'pendingFinds';
  static const String _offlineFindsBoxName = 'offline_finds';

  // Cajas almacenadas en memoria
  static Box? _findBox;
  static Box? _offlineFindsBox;

  static bool isInitialized = false;

  // Inicializar Hive para "finds"
  static Future<void> initialize() async {
    if (isInitialized) {
      print('HiveFindStorage: Already initialized');
      return;
    }

    try {
      print('HiveFindStorage: Initializing Hive...');

      _findBox = await _openBoxIfNeeded(_findBoxName);
      _offlineFindsBox = await _openBoxIfNeeded(_offlineFindsBoxName);

      isInitialized = true;
      print('HiveFindStorage: Initialization complete');
    } catch (e) {
      print('HiveFindStorage: Error initializing storage: $e');
      isInitialized = false;
      rethrow;
    }
  }

  static Future<Map<String, Map<String, dynamic>>> getAllFinds() async {
  final box = _offlineFindsBox ??= await _openBoxIfNeeded(_offlineFindsBoxName);
  return box.toMap().map((key, value) {
    // Convertir explícitamente cada valor en un Map<String, dynamic>
    return MapEntry(key as String, Map<String, dynamic>.from(value as Map));
  });
  }

  // Abrir la caja si no está abierta aún
  static Future<Box> _openBoxIfNeeded(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box(name);
    } else {
      return await Hive.openBox(name);
    }
  }

  // Guardar un "find" localmente
  static Future<void> saveFind(Map<String, dynamic> find) async {
    final box = _offlineFindsBox ??= await _openBoxIfNeeded(_offlineFindsBoxName);
    final key = DateTime.now().millisecondsSinceEpoch.toString(); // clave única
    await box.put(key, find);
    print('HiveFindStorage: Saved find with key $key');
  }


  // Eliminar un "find" después de subirlo
  static Future<void> deleteFind(String key) async {
    final box = _offlineFindsBox ??= await _openBoxIfNeeded(_offlineFindsBoxName);
    await box.delete(key);
    print('HiveFindStorage: Deleted find with key $key');
  }

  // Limpiar todos los "finds" locales
  static Future<void> clearAllFinds() async {
    try {
      final box = _findBox ??= await _openBoxIfNeeded(_findBoxName);
      await box.clear();
      print('HiveFindStorage: All finds cleared');
    } catch (e) {
      print('HiveFindStorage: Error clearing finds: $e');
    }
  }
}
