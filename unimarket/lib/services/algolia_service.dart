import 'package:algolia/algolia.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/services/algolia_adapter_service.dart';

class AlgoliaService {
  // Singleton pattern
  static final AlgoliaService _instance = AlgoliaService._internal();
  factory AlgoliaService() => _instance;
  AlgoliaService._internal();

  // Initialize Algolia
  final Algolia _algolia = const Algolia.init(
    applicationId: 'BN577CB6P8',
    apiKey: 'dc1ff8ca6c391a652b422a4ef11c8fd3', // Reemplaza con tu API key (solo de búsqueda)
  );

  // Cache for search results to avoid repeated API calls
  final Map<String, List<ProductModel>> _searchCache = {};

  // Search history limit
  final int _historyLimit = 10;

  // Get the Algolia instance
  Algolia get algolia => _algolia;
// Search for products with query
  Future<List<ProductModel>> searchProducts(String query) async {
    // Check if the result is in cache
    if (_searchCache.containsKey(query)) {
      print('Using cached results for query: $query');
      return _searchCache[query]!;
    }

    try {
      // Perform the search
      AlgoliaQuery algoliaQuery = _algolia.instance.index('product')
          .query(query)
          .setHitsPerPage(50);
          
      AlgoliaQuerySnapshot snapshot = await algoliaQuery.getObjects();
      
      // Depuración - imprimir el primer resultado para ver su estructura
      if (snapshot.hits.isNotEmpty) {
        print('Sample hit data:');
        print(snapshot.hits.first.data);
      }
      
      // Usar el adaptador para convertir los datos de Algolia a ProductModel
      List<ProductModel> products = snapshot.hits.map((hit) {
        return AlgoliaAdapter.convertToProductModel(hit.data);
      }).toList();
      
      // Save to cache
      _searchCache[query] = products;
      
      // Add to search history
      await _addToSearchHistory(query);
      
      return products;
    } catch (e) {
      print('Error searching in Algolia: $e');
      return [];
    }
  }
  

  // Clear cache for a specific query or all cache if query is null
  void clearCache({String? query}) {
    if (query != null) {
      _searchCache.remove(query);
    } else {
      _searchCache.clear();
    }
  }

  // Add search query to history
  Future<void> _addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> history = await getSearchHistory();
      
      // Remove query if already exists to avoid duplication
      history.removeWhere((element) => element.toLowerCase() == query.toLowerCase());
      
      // Add query at the beginning of the list
      history.insert(0, query);
      
      // Limit the history size
      if (history.length > _historyLimit) {
        history = history.sublist(0, _historyLimit);
      }
      
      // Save back to SharedPreferences
      await prefs.setStringList('search_history', history);
    } catch (e) {
      print('Error adding to search history: $e');
    }
  }

  // Get search history
  Future<List<String>> getSearchHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('search_history') ?? [];
    } catch (e) {
      print('Error getting search history: $e');
      return [];
    }
  }

  // Clear search history
  Future<void> clearSearchHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('search_history');
    } catch (e) {
      print('Error clearing search history: $e');
    }
  }
}