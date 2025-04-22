import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:unimarket/models/product_model.dart';


class ProductCacheService {
  static final ProductCacheService _instance = ProductCacheService._internal();
  factory ProductCacheService() => _instance;
  ProductCacheService._internal();

  // 1. CacheManager para datos de productos (JSON)
  final CacheManager _jsonCache = CacheManager(
    Config(
      'productJsonCache',               // clave única
      stalePeriod: Duration(days: 1),   // caduca en 1 día
      maxNrOfCacheObjects: 1,           // solo guardamos 1 archivo
    ),
  );

  /// Guardar lista de productos en cache (como JSON)
  Future<void> saveFilteredProducts(List<ProductModel> products) async {
    final jsonList   = products.map((p) => p.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    // 1.1 Guardamos el JSON en cache
    await _jsonCache.putFile(
      'filtered_products',               // key interna
      utf8.encode(jsonString),           // bytes del JSON
      fileExtension: 'json',
    );

    // 1.2 Precargar en cache las imágenes (en disco)
    await Future.wait(products.map((p) => _cacheImage(p.imageUrls.first)));
  }

  /// Cargar lista de productos desde cache
  Future<List<ProductModel>> loadFilteredProducts() async {
    final fileInfo = await _jsonCache.getFileFromCache('filtered_products');
    if (fileInfo != null && await fileInfo.file.exists()) {
      final jsonString = await fileInfo.file.readAsString();
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => ProductModel.fromJson(e)).toList();
    }
    return [];
  }

  // --------------------------------------------------
  // 2. Helpers para cachear imágenes con DefaultCacheManager
  // --------------------------------------------------

  Future<void> _cacheImage(String? url) async {
    if (url == null) return;
    try {
      await DefaultCacheManager().getSingleFile(url);
    } catch (_) {
      // si falla, no hacemos nada
    }
  }

  /// Devuelve un ImageProvider que usa la imagen cacheada (si existe)
  /// o la descarga y cachea en disco antes de mostrarla.
  Future<ImageProvider> getImageProvider(String url) async {
    try {
      // intentar obtener del cache en disco
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);
      final file     = fileInfo?.file ?? await DefaultCacheManager().getSingleFile(url);
      return FileImage(file);
    } catch (_) {
      // fallback a descarga normal si algo falla
      return NetworkImage(url);
    }
  }
}
