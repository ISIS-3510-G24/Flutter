import 'dart:collection';
import 'package:algolia/algolia.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/services/algolia_adapter_service.dart';

/// ArrayMap: un cache de tamaño fijo que expulsa la entrada
/// menos recientemente usada (LRU) cuando supera [capacity].
///
/// Parámetros:
/// - [capacity]: número máximo de entradas que retiene en memoria.
class ArrayMap<K, V> {
  final int capacity;
  final LinkedHashMap<K, V> _map;

  ArrayMap(this.capacity) : _map = LinkedHashMap();

  /// Obtiene el valor y lo marca como usado (se mueve al final de la lista).
  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    V value = _map.remove(key)!;
    _map[key] = value;
    return value;
  }

  /// Inserta o actualiza el valor. Si no existe y estamos al límite,
  /// elimina la clave más antigua (_map.keys.first).
  void put(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    } else if (_map.length >= capacity) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  bool containsKey(K key) => _map.containsKey(key);
  void remove(K key) => _map.remove(key);
  void clear() => _map.clear();
}

/// Servicio de búsqueda con Algolia y caché LRU en memoria.
class AlgoliaService {
  // Singleton pattern
  static final AlgoliaService _instance = AlgoliaService._internal();
  factory AlgoliaService() => _instance;
  AlgoliaService._internal();

  // Inicialización de Algolia
  final Algolia _algolia = const Algolia.init(
    applicationId: 'BN577CB6P8',
    apiKey: 'dc1ff8ca6c391a652b422a4ef11c8fd3', // Solo búsqueda
  );

  // Caché LRU en memoria: capacidad máxima de 20 entradas.
  final ArrayMap<String, List<ProductModel>> _searchCache = ArrayMap(20);

  // Límite de historial de búsqueda en SharedPreferences
  final int _historyLimit = 10;

  Algolia get algolia => _algolia;

  /// Busca productos. Usa caché LRU para no repetir llamadas idénticas.
  Future<List<ProductModel>> searchProducts(String query) async {
    // 1) Intentar leer de caché
    final cached = _searchCache.get(query);
    if (cached != null) {
      print('Usando caché para query: $query');
      return cached;
    }

    try {
      // 2) Si no está en caché, consulta a Algolia
      AlgoliaQuery algoliaQuery = _algolia.instance
          .index('product')
          .query(query)
          .setHitsPerPage(50);

      AlgoliaQuerySnapshot snapshot = await algoliaQuery.getObjects();

      if (snapshot.hits.isNotEmpty) {
        print('Sample hit data: ${snapshot.hits.first.data}');
      }

      // 3) Convertir a ProductModel
      List<ProductModel> products = snapshot.hits
          .map((hit) => AlgoliaAdapter.convertToProductModel(hit.data))
          .toList();

      // 4) Guardar en caché
      _searchCache.put(query, products);

      // 5) Actualizar historial de búsqueda
      await _addToSearchHistory(query);

      return products;
    } catch (e) {
      print('Error searching in Algolia: $e');
      return [];
    }
  }

  /// Limpia caché completo o de una query específica.
  void clearCache({String? query}) {
    if (query != null) {
      _searchCache.remove(query);
    } else {
      _searchCache.clear();
    }
  }

  // --- Gestión de historial en SharedPreferences ---

  Future<void> _addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> history = await getSearchHistory();

      // Evitar duplicados
      history.removeWhere((e) => e.toLowerCase() == query.toLowerCase());
      history.insert(0, query);

      // Mantener solo las últimas [_historyLimit]
      if (history.length > _historyLimit) {
        history = history.sublist(0, _historyLimit);
      }

      await prefs.setStringList('search_history', history);
    } catch (e) {
      print('Error adding to search history: $e');
    }
  }

  Future<List<String>> getSearchHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('search_history') ?? [];
    } catch (e) {
      print('Error getting search history: $e');
      return [];
    }
  }

  Future<void> clearSearchHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('search_history');
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }
}
