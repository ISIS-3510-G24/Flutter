import 'package:algolia/algolia.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/services/algolia_adapter_service.dart';

/// ArrayMap: estructura de datos que almacena elementos en arrays para optimizar
/// el uso de memoria a costa de un poco de rendimiento.
///
/// Parámetros:
/// - [capacity]: número máximo de entradas que retiene en memoria.
class ArrayMap<K, V> {
  final int capacity;
  final List<int> _hashes;      // Array para almacenar los hashes
  final List<dynamic> _entries; // Array para almacenar claves y valores de forma intercalada

  ArrayMap(this.capacity) 
      : _hashes = [],
        _entries = [];

  /// Obtiene el valor asociado a la clave proporcionada.
  V? get(K key) {
    final hash = key.hashCode;
    final index = _binarySearch(hash);
    
    if (index >= 0) {
      // Encontramos un hash que coincide, pero debemos verificar que la clave sea exactamente la misma
      final entryIndex = index * 2;
      if (_entries[entryIndex] == key) {
        return _entries[entryIndex + 1] as V;
      }
      
      // Si hay colisión de hash, buscar linealmente
      int i = index - 1;
      while (i >= 0 && _hashes[i] == hash) {
        if (_entries[i * 2] == key) {
          return _entries[i * 2 + 1] as V;
        }
        i--;
      }
      
      i = index + 1;
      while (i < _hashes.length && _hashes[i] == hash) {
        if (_entries[i * 2] == key) {
          return _entries[i * 2 + 1] as V;
        }
        i++;
      }
    }
    
    return null;
  }

  /// Inserta o actualiza el valor. Si estamos al límite de capacidad,
  /// no se añadirá el nuevo elemento.
  void put(K key, V value) {
    final hash = key.hashCode;
    final index = _binarySearch(hash);
    
    if (index >= 0) {
      // Hash encontrado, revisar si la clave existe
      int i = index;
      while (i >= 0 && _hashes[i] == hash) {
        if (_entries[i * 2] == key) {
          // Actualizar valor existente
          _entries[i * 2 + 1] = value;
          return;
        }
        i--;
      }
      
      i = index + 1;
      while (i < _hashes.length && _hashes[i] == hash) {
        if (_entries[i * 2] == key) {
          // Actualizar valor existente
          _entries[i * 2 + 1] = value;
          return;
        }
        i++;
      }
      
      // Insertar nuevo par (key, value) con el mismo hash
      _insertAt(index + 1, key, value, hash);
    } else {
      // Hash no encontrado, calculamos el punto de inserción
      final insertionPoint = -(index + 1);
      _insertAt(insertionPoint, key, value, hash);
    }
  }

  /// Inserta un par clave-valor en la posición específica
  void _insertAt(int index, K key, V value, int hash) {
    if (_hashes.length >= capacity) {
      // Si alcanzamos capacidad, no insertamos más elementos
      return;
    }
    
    // Insertar hash
    _hashes.insert(index, hash);
    
    // Insertar clave y valor
    final entryIndex = index * 2;
    if (entryIndex >= _entries.length) {
      _entries.add(key);
      _entries.add(value);
    } else {
      _entries.insert(entryIndex, key);
      _entries.insert(entryIndex + 1, value);
    }
  }

  /// Búsqueda binaria para encontrar el hash
  int _binarySearch(int hash) {
    int low = 0;
    int high = _hashes.length - 1;
    
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final midVal = _hashes[mid];
      
      if (midVal < hash) {
        low = mid + 1;
      } else if (midVal > hash) {
        high = mid - 1;
      } else {
        return mid; // Clave encontrada
      }
    }
    
    return -(low + 1); // Clave no encontrada, retorna punto de inserción
  }

  bool containsKey(K key) => get(key) != null;

  void remove(K key) {
    final hash = key.hashCode;
    final index = _binarySearch(hash);
    
    if (index >= 0) {
      // Buscar la clave exacta
      int i = index;
      while (i >= 0 && _hashes[i] == hash) {
        if (_entries[i * 2] == key) {
          _hashes.removeAt(i);
          _entries.removeAt(i * 2); // Eliminar clave
          _entries.removeAt(i * 2); // Eliminar valor
          return;
        }
        i--;
      }
      
      i = index + 1;
      while (i < _hashes.length && _hashes[i] == hash) {
        if (_entries[i * 2] == key) {
          _hashes.removeAt(i);
          _entries.removeAt(i * 2); // Eliminar clave
          _entries.removeAt(i * 2); // Eliminar valor
          return;
        }
        i++;
      }
    }
  }

  void clear() {
    _hashes.clear();
    _entries.clear();
  }
}

/// Servicio de búsqueda con Algolia y caché ArrayMap en memoria.
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

  // Caché ArrayMap en memoria: capacidad máxima de 20 entradas.
  final ArrayMap<String, List<ProductModel>> _searchCache = ArrayMap(20);

  // Límite de historial de búsqueda en SharedPreferences
  final int _historyLimit = 20;

  Algolia get algolia => _algolia;

  /// Busca productos. Usa caché ArrayMap para no repetir llamadas idénticas.
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

  Future<void> addSearchToHistory(String query) async {
    return _addToSearchHistory(query);
  }
}