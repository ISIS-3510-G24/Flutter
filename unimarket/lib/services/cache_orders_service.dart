import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheOrdersService<K, V> {
  final int capacity; // Capacidad máxima del caché
  final _cache = <K, V>{}; // Mapa para almacenar las órdenes individuales
  final _usageOrder = <K>[]; // Lista para mantener el orden de uso
  final String storageKey; // Clave para almacenamiento persistente

  CacheOrdersService(this.capacity, this.storageKey);

  /// Carga los datos desde SharedPreferences al iniciar
  Future<void> loadFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final cachedData = prefs.getString(storageKey);
  if (cachedData != null) {
    try {
      final decodedData = jsonDecode(cachedData) as Map<String, dynamic>;
      _cache.clear();
      _usageOrder.clear();
      decodedData.forEach((key, value) {
        // Verifica que cada valor sea un Map<String, dynamic>
        if (value is Map<String, dynamic>) {
          _cache[key as K] = value as V;
          _usageOrder.add(key as K);
        } else {
          print("Invalid data format for key: $key");
        }
      });
      print("Cache successfully loaded from storage: ${_cache.length} items");
    } catch (e) {
      print("Error loading cache from storage: $e");
    }
  } else {
    print("No cached data found in storage.");
  }
}

  /// Guarda los datos actuales del caché en SharedPreferences
 Future<void> saveToStorage() async {
  final prefs = await SharedPreferences.getInstance();
  try {
    final encodedData = jsonEncode(_cache); // Convierte el mapa a JSON
    await prefs.setString(storageKey, encodedData);
    print("Cache successfully saved to storage: ${_cache.length} items");
  } catch (e) {
    print("Error saving cache to storage: $e");
  }
}

  /// Obtiene una orden del caché
  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    _usageOrder.remove(key); // Elimina la clave de su posición actual
    _usageOrder.add(key); // Agrega la clave al final (más recientemente utilizada)
    print("Accessed key: $key. Usage order: $_usageOrder");
    return _cache[key];
  }

  /// Agrega una nueva orden al caché
  Future<void> put(K key, V value) async {
  if (_cache.containsKey(key)) {
    _usageOrder.remove(key); // Elimina la clave de su posición actual
  } else if (_cache.length >= capacity) {
    K oldestKey = _usageOrder.removeAt(0); // Elimina la clave menos recientemente utilizada
    _cache.remove(oldestKey); // Elimina el elemento del caché
    print("Removed least recently used order: $oldestKey");
  }
  _cache[key] = value; // Agrega el nuevo valor al caché
  _usageOrder.add(key); // Agrega la clave al final (más recientemente utilizada)
  print("Added order to cache: $key. Current cache size: ${_cache.length}");
  print("Current usage order: $_usageOrder");
  await saveToStorage(); // Guarda los datos en almacenamiento persistente
}

  /// Limpia todo el caché
  Future<void> clear() async {
    _cache.clear();
    _usageOrder.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey); // Limpia el almacenamiento persistente
  }
}