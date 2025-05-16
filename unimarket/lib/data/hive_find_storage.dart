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
  final finds = box.toMap().map((key, value) {
    return MapEntry(key as String, Map<String, dynamic>.from(value as Map));
  });
  print('HiveFindStorage: Retrieved ${finds.length} finds from cache');
  return finds;
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
  print('HiveFindStorage: Current cache size: ${box.length}');
}

  // Eliminar un "find" después de subirlo
  static Future<void> deleteFind(String key) async {
    final box = _offlineFindsBox ??= await _openBoxIfNeeded(_offlineFindsBoxName);
    await box.delete(key);
    print('HiveFindStorage: Deleted find with key $key');
  }

  static Future<void> clearAllFinds() async {
  try {
    final findBox = _findBox ??= await _openBoxIfNeeded(_findBoxName);
    final offlineBox = _offlineFindsBox ??= await _openBoxIfNeeded(_offlineFindsBoxName);

    // Limpia la caja "findBox"
    await findBox.clear();
    print('HiveFindStorage: Cleared findBox. Current size: ${findBox.length}');

    // Limpia la caja "offlineBox"
    await offlineBox.clear();
    print('HiveFindStorage: Cleared offlineBox. Current size: ${offlineBox.length}');

    // Confirmación final
    print('HiveFindStorage: All finds cleared from both boxes');
  } catch (e) {
    print('HiveFindStorage: Error clearing finds: $e');
  }
}

}
