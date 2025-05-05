import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheOrdersService<K, V> {
  final int capacity;
  final _cache = <K, V>{};
  final _usageOrder = <K>[];
  final String storageKey;

  CacheOrdersService(this.capacity, this.storageKey);

  Future<void> loadFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final cachedData = prefs.getString(storageKey);
  if (cachedData != null) {
    final decodedData = jsonDecode(cachedData) as Map<String, dynamic>;
    _cache.clear();
    _usageOrder.clear();
    decodedData.forEach((key, value) {
      // Convierte explícitamente cada valor en un List<Map<String, dynamic>>
      _cache[key as K] = (value as List)
          .map((item) => item as Map<String, dynamic>)
          .toList() as V;
      _usageOrder.add(key as K);
    });
  }
}

  Future<void> saveToStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final encodedData = jsonEncode(_cache);
  await prefs.setString(storageKey, encodedData);
}

  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    _usageOrder.remove(key);
    _usageOrder.add(key);
    return _cache[key];
  }

 Future<void> put(K key, V value) async {
  if (_cache.containsKey(key)) {
    _usageOrder.remove(key);
  } else if (_cache.length >= capacity) {
    K oldestKey = _usageOrder.removeAt(0);
    _cache.remove(oldestKey);
  }
  _cache[key] = value;
  _usageOrder.add(key);
  await saveToStorage(); // Guarda los datos en almacenamiento persistente
}

  Future<void> clear() async {
  _cache.clear();
  _usageOrder.clear();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(storageKey); // Limpia el almacenamiento persistente
  print("SharedPreferences cleared for key: $storageKey");
}
}