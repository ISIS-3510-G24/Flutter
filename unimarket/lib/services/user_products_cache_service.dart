// lib/services/user_products_cache_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/services/connectivity_service.dart';

/// Specialized cache service for user-specific products
/// Extends the general product caching with user-specific functionality
class UserProductsCacheService {
  static final UserProductsCacheService _instance = UserProductsCacheService._internal();
  factory UserProductsCacheService() => _instance;
  UserProductsCacheService._internal();

  // Dependencies
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Cache manager for user-specific products
  final CacheManager _userProductsCache = CacheManager(
    Config(
      'userProductsCache',
      stalePeriod: const Duration(hours: 2), // User products can change more frequently
      maxNrOfCacheObjects: 100, // Allow more user-specific caches
    ),
  );
  
  // In-memory cache for recently accessed user products
  final Map<String, List<ProductModel>> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _memoryCacheExpiry = Duration(minutes: 10);

  /// Get products for a specific user with comprehensive caching
  Future<List<ProductModel>> getUserProducts(String userId, {bool forceRefresh = false}) async {
    try {
      print('UserProductsCache: Getting products for user $userId');
      
      // Step 1: Check memory cache first (fastest)
      if (!forceRefresh) {
        final memoryCachedProducts = _getFromMemoryCache(userId);
        if (memoryCachedProducts != null) {
          print('UserProductsCache: Using memory cache (${memoryCachedProducts.length} products)');
          
          // Refresh in background if online
          _refreshUserProductsInBackground(userId);
          
          return memoryCachedProducts;
        }
      }
      
      // Step 2: Check disk cache (fast)
      if (!forceRefresh) {
        final diskCachedProducts = await _getFromDiskCache(userId);
        if (diskCachedProducts.isNotEmpty) {
          print('UserProductsCache: Using disk cache (${diskCachedProducts.length} products)');
          
          // Add to memory cache
          _addToMemoryCache(userId, diskCachedProducts);
          
          // Refresh in background if online
          _refreshUserProductsInBackground(userId);
          
          return diskCachedProducts;
        }
      }
      
      // Step 3: Check connectivity before network request
      final hasInternet = await _connectivityService.checkConnectivity();
      if (!hasInternet && !forceRefresh) {
        print('UserProductsCache: Offline - returning empty list');
        return [];
      }
      
      // Step 4: Fetch from network (slow but fresh)
      if (hasInternet) {
        return await _fetchFromNetworkAndCache(userId);
      } else {
        print('UserProductsCache: No connection and no cached data');
        return [];
      }
      
    } catch (e) {
      print('UserProductsCache: Error getting user products: $e');
      
      // Fallback: try to get anything from cache
      final fallbackProducts = _getFromMemoryCache(userId) ?? 
                              await _getFromDiskCache(userId);
      return fallbackProducts;
    }
  }

  /// Check memory cache for user products
  List<ProductModel>? _getFromMemoryCache(String userId) {
    if (!_memoryCache.containsKey(userId)) return null;
    
    final cacheTime = _cacheTimestamps[userId];
    if (cacheTime == null) return null;
    
    // Check if cache is still valid
    if (DateTime.now().difference(cacheTime) > _memoryCacheExpiry) {
      _memoryCache.remove(userId);
      _cacheTimestamps.remove(userId);
      return null;
    }
    
    return _memoryCache[userId];
  }

  /// Add products to memory cache
  void _addToMemoryCache(String userId, List<ProductModel> products) {
    _memoryCache[userId] = products;
    _cacheTimestamps[userId] = DateTime.now();
    
    // Clean old entries if cache gets too large
    if (_memoryCache.length > 20) {
      _cleanOldMemoryCacheEntries();
    }
  }

  /// Clean old memory cache entries
  void _cleanOldMemoryCacheEntries() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _memoryCacheExpiry) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    print('UserProductsCache: Cleaned ${keysToRemove.length} old memory cache entries');
  }

  /// Get products from disk cache
  Future<List<ProductModel>> _getFromDiskCache(String userId) async {
    try {
      final cacheKey = 'user_products_$userId';
      final fileInfo = await _userProductsCache.getFileFromCache(cacheKey);
      
      if (fileInfo != null && await fileInfo.file.exists()) {
        final jsonString = await fileInfo.file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        
        final products = jsonList.map((json) => ProductModel.fromJson(json)).toList();
        print('UserProductsCache: Loaded ${products.length} products from disk cache');
        
        return products;
      }
    } catch (e) {
      print('UserProductsCache: Error reading from disk cache: $e');
    }
    
    return [];
  }

  /// Fetch products from network and cache them
  Future<List<ProductModel>> _fetchFromNetworkAndCache(String userId) async {
    try {
      print('UserProductsCache: Fetching from network for user $userId');
      
      final productMaps = await _firebaseDAO.getProductsByUserId(userId)
          .timeout(const Duration(seconds: 15));
      
      final products = productMaps
          .map((map) => ProductModel.fromMap(map, docId: map['id']))
          .toList();
      
      print('UserProductsCache: Fetched ${products.length} products from network');
      
      // Cache the results
      await _saveToDiskCache(userId, products);
      _addToMemoryCache(userId, products);
      
      return products;
    } catch (e) {
      print('UserProductsCache: Error fetching from network: $e');
      
      // Try to return cached data as fallback
      final fallbackProducts = _getFromMemoryCache(userId) ?? 
                              await _getFromDiskCache(userId);
      
      if (fallbackProducts.isNotEmpty) {
        print('UserProductsCache: Using fallback cached data');
        return fallbackProducts;
      }
      
      rethrow;
    }
  }

  /// Save products to disk cache
  Future<void> _saveToDiskCache(String userId, List<ProductModel> products) async {
    try {
      final cacheKey = 'user_products_$userId';
      final jsonList = products.map((product) => product.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await _userProductsCache.putFile(
        cacheKey,
        utf8.encode(jsonString),
        fileExtension: 'json',
      );
      
      print('UserProductsCache: Saved ${products.length} products to disk cache');
    } catch (e) {
      print('UserProductsCache: Error saving to disk cache: $e');
    }
  }

  /// Refresh user products in background
  void _refreshUserProductsInBackground(String userId) {
    // Don't await this - let it run in background
    Future.delayed(Duration.zero, () async {
      try {
        final hasInternet = await _connectivityService.checkConnectivity();
        if (!hasInternet) return;
        
        print('UserProductsCache: Background refresh for user $userId');
        
        final productMaps = await _firebaseDAO.getProductsByUserId(userId)
            .timeout(const Duration(seconds: 10));
        
        final products = productMaps
            .map((map) => ProductModel.fromMap(map, docId: map['id']))
            .toList();
        
        // Update caches
        await _saveToDiskCache(userId, products);
        _addToMemoryCache(userId, products);
        
        print('UserProductsCache: Background refresh completed - ${products.length} products');
      } catch (e) {
        print('UserProductsCache: Background refresh error for $userId: $e');
      }
    });
  }

  /// Preload products for multiple users
  Future<void> preloadUserProducts(List<String> userIds) async {
    if (userIds.isEmpty) return;
    
    print('UserProductsCache: Preloading products for ${userIds.length} users');
    
    final hasInternet = await _connectivityService.checkConnectivity();
    if (!hasInternet) {
      print('UserProductsCache: Offline - skipping preload');
      return;
    }
    
    // Process users in parallel with reasonable concurrency
    final futures = userIds.map((userId) => _preloadSingleUser(userId));
    await Future.wait(futures);
    
    print('UserProductsCache: Preload completed');
  }

  /// Preload products for a single user
  Future<void> _preloadSingleUser(String userId) async {
    try {
      // Check if we already have recent data
      final memoryCache = _getFromMemoryCache(userId);
      if (memoryCache != null) {
        print('UserProductsCache: Skipping preload for $userId (already in memory)');
        return;
      }
      
      // Check disk cache age
      final diskCache = await _getFromDiskCache(userId);
      if (diskCache.isNotEmpty) {
        // Add to memory cache and skip network request
        _addToMemoryCache(userId, diskCache);
        print('UserProductsCache: Preloaded from disk for $userId');
        return;
      }
      
      // Fetch from network
      await _fetchFromNetworkAndCache(userId);
      print('UserProductsCache: Preloaded from network for $userId');
      
    } catch (e) {
      print('UserProductsCache: Error preloading for $userId: $e');
    }
  }

  /// Invalidate cache for a specific user (when they update products)
  Future<void> invalidateUserCache(String userId) async {
    try {
      print('UserProductsCache: Invalidating cache for user $userId');
      
      // Remove from memory cache
      _memoryCache.remove(userId);
      _cacheTimestamps.remove(userId);
      
      // Remove from disk cache
      final cacheKey = 'user_products_$userId';
      await _userProductsCache.removeFile(cacheKey);
      
      print('UserProductsCache: Cache invalidated for user $userId');
    } catch (e) {
      print('UserProductsCache: Error invalidating cache: $e');
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    try {
      print('UserProductsCache: Clearing all caches');
      
      // Clear memory cache
      _memoryCache.clear();
      _cacheTimestamps.clear();
      
      // Clear disk cache
      await _userProductsCache.emptyCache();
      
      print('UserProductsCache: All caches cleared');
    } catch (e) {
      print('UserProductsCache: Error clearing caches: $e');
    }
  }

  /// Get cache statistics for debugging
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final memoryCacheSize = _memoryCache.length;
      final totalProductsInMemory = _memoryCache.values
          .fold<int>(0, (sum, products) => sum + products.length);
      
      return {
        'memoryCacheUsers': memoryCacheSize,
        'totalProductsInMemory': totalProductsInMemory,
        'oldestMemoryEntry': _cacheTimestamps.values.isEmpty 
            ? null 
            : _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String(),
        'newestMemoryEntry': _cacheTimestamps.values.isEmpty 
            ? null 
            : _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b).toIso8601String(),
      };
    } catch (e) {
      print('UserProductsCache: Error getting cache stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Check if user has cached products
  Future<bool> hasUserProducts(String userId) async {
    // Check memory first
    if (_getFromMemoryCache(userId) != null) {
      return true;
    }
    
    // Check disk cache
    final diskProducts = await _getFromDiskCache(userId);
    return diskProducts.isNotEmpty;
  }

  /// Get the number of cached products for a user without loading them
  Future<int> getUserProductCount(String userId) async {
    // Check memory first
    final memoryProducts = _getFromMemoryCache(userId);
    if (memoryProducts != null) {
      return memoryProducts.length;
    }
    
    // Check disk cache
    final diskProducts = await _getFromDiskCache(userId);
    return diskProducts.length;
  }
}