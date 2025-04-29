import 'package:hive_flutter/hive_flutter.dart';

class HiveOfferStorage {
  // Nombre de la caja
  static const String _offerBoxName = 'pendingOffers';

  // Caja almacenada en memoria
  static Box? _offerBox;

  static bool isInitialized = false;

  // Inicializar Hive para "offers"
  static Future<void> initialize() async {
    if (isInitialized) {
      print('HiveOfferStorage: Already initialized');
      return;
    }

    try {
      print('HiveOfferStorage: Initializing Hive...');
      _offerBox = await _openBoxIfNeeded(_offerBoxName);
      isInitialized = true;
      print('HiveOfferStorage: Initialization complete');
    } catch (e) {
      print('HiveOfferStorage: Error initializing storage: $e');
      isInitialized = false;
      rethrow;
    }
  }

  // Abrir la caja si no está abierta aún
  static Future<Box> _openBoxIfNeeded(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box(name);
    } else {
      return await Hive.openBox(name);
    }
  }

  // Guardar un "offer" localmente
  static Future<void> saveOffer(Map<String, dynamic> offer) async {
    final box = _offerBox ??= await _openBoxIfNeeded(_offerBoxName);
    final key = DateTime.now().millisecondsSinceEpoch.toString(); // clave única
    await box.put(key, offer);
    print('HiveOfferStorage: Saved offer with key $key');
  }

  // Obtener todos los "offers" guardados localmente
  static Future<Map<String, Map<String, dynamic>>> getAllOffers() async {
    final box = _offerBox ??= await _openBoxIfNeeded(_offerBoxName);
    return Map<String, Map<String, dynamic>>.from(box.toMap());
  }

  // Eliminar un "offer" después de subirlo
  static Future<void> deleteOffer(String key) async {
    final box = _offerBox ??= await _openBoxIfNeeded(_offerBoxName);
    await box.delete(key);
    print('HiveOfferStorage: Deleted offer with key $key');
  }

  // Limpiar todos los "offers" locales
  static Future<void> clearAllOffers() async {
    try {
      final box = _offerBox ??= await _openBoxIfNeeded(_offerBoxName);
      await box.clear();
      print('HiveOfferStorage: All offers cleared');
    } catch (e) {
      print('HiveOfferStorage: Error clearing offers: $e');
    }
  }
}