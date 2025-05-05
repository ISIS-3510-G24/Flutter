import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();
  
  static Database? _database;
  static const String _dbName = 'image_cache.db';
  static const String _tableName = 'cached_images';
  static const int _dbVersion = 1;
  
  final Map<String, Future<File?>> _downloadOperations = {};
  final Map<String, File> _memoryCache = {};
  
  // Inicializar base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  // Crear base de datos
  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _dbName);
      
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE $_tableName (
            url TEXT PRIMARY KEY,
            localPath TEXT NOT NULL,
            lastUpdated INTEGER NOT NULL,
            etag TEXT,
            fileSize INTEGER
          )
          ''');
        },
      );
    } catch (e) {
      print('ImageCacheService: Error initializing database: $e');
      // Fallback to in-memory database if file database fails
      return await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE $_tableName (
            url TEXT PRIMARY KEY,
            localPath TEXT NOT NULL,
            lastUpdated INTEGER NOT NULL,
            etag TEXT,
            fileSize INTEGER
          )
          ''');
        }
      );
    }
  }
  
  // Verificar si existe una imagen en caché
  Future<bool> hasCachedImage(String? url) async {
    if (url == null || url.isEmpty) return false;
    
    try {
      // Check memory cache first (fastest)
      if (_memoryCache.containsKey(url)) {
        return await _memoryCache[url]!.exists();
      }
      
      // Check database
      final cachedPath = await getCachedImagePath(url);
      if (cachedPath != null) {
        final file = File(cachedPath);
        return await file.exists();
      }
      
      return false;
    } catch (e) {
      print('ImageCacheService: Error checking cached image: $e');
      return false;
    }
  }
  
  // Obtener imagen desde URL (con caché)
  Future<File?> getImageFile(String? url) async {
    if (url == null || url.isEmpty) {
      return null;
    }
    
    try {
      // Check if we already have this download in progress
      if (_downloadOperations.containsKey(url)) {
        return await _downloadOperations[url]!;
      }
      
      // Check memory cache first
      if (_memoryCache.containsKey(url)) {
        final file = _memoryCache[url]!;
        if (await file.exists()) {
          return file;
        }
      }
      
      // Check database cache
      final cachedPath = await getCachedImagePath(url);
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          // Add to memory cache
          _memoryCache[url] = file;
          return file;
        }
      }
      
      // If not in cache, download with deduplication
      final downloadFuture = downloadAndCacheImage(url);
      _downloadOperations[url] = downloadFuture;
      
      final file = await downloadFuture;
      
      // Remove from operations after download (whether successful or not)
      _downloadOperations.remove(url);
      
      return file;
    } catch (e) {
      print('ImageCacheService: Error getting image file: $e');
      _downloadOperations.remove(url);
      return null;
    }
  }
  
  // Obtener imagen como ImageProvider
  Future<ImageProvider> getImageProvider(String? url, {ImageProvider? placeholder}) async {
    if (url == null || url.isEmpty) {
      return placeholder ?? const AssetImage('assets/images/Avatar.png');
    }
    
    try {
      final file = await getImageFile(url);
      
      if (file != null && await file.exists()) {
        return FileImage(file);
      }
    } catch (e) {
      print('ImageCacheService: Error getting image provider: $e');
    }
    
    // Retornar placeholder si falla
    return placeholder ?? const AssetImage('assets/images/Avatar.png');
  }
  
  // Descargar y almacenar en caché
  Future<File?> downloadAndCacheImage(String url) async {
    try {
      print('ImageCacheService: Downloading image: $url');
      
      // Try to get from web with timeout
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final file = await _saveImageToCache(url, response.bodyBytes);
        if (file != null) {
          // Add to memory cache
          _memoryCache[url] = file;
        }
        return file;
      } else {
        print('ImageCacheService: Failed to download image, status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('ImageCacheService: Error downloading image: $e');
      return null;
    }
  }
  
  // Guardar imagen en caché
  Future<File?> _saveImageToCache(String url, List<int> imageBytes) async {
    try {
      // Generar nombre de archivo basado en hash de URL
      final hash = sha1.convert(utf8.encode(url)).toString();
      
      // Obtener directorio de caché
      final cacheDir = await _getCacheDirectory();
      final file = File('${cacheDir.path}/$hash.jpg');
      
      // Guardar imagen
      await file.writeAsBytes(imageBytes);
      
      // Actualizar base de datos
      await _saveImagePathToDb(url, file.path, imageBytes.length);
      
      print('ImageCacheService: Image saved to cache: ${file.path}');
      return file;
    } catch (e) {
      print('ImageCacheService: Error saving image to cache: $e');
      return null;
    }
  }
  
  // Obtener directorio de caché
  Future<Directory> _getCacheDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/image_cache');
      
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      return cacheDir;
    } catch (e) {
      print('ImageCacheService: Error getting cache directory: $e');
      // Fallback to temp directory if can't create cache dir
      return await Directory.systemTemp.createTemp('image_cache');
    }
  }
  
  // Guardar ruta de imagen en base de datos
  Future<void> _saveImagePathToDb(String url, String localPath, int fileSize) async {
    try {
      final db = await database;
      
      await db.insert(
        _tableName,
        {
          'url': url,
          'localPath': localPath,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
          'fileSize': fileSize
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('ImageCacheService: Error saving image path to db: $e');
    }
  }
  
  // Obtener ruta de imagen en caché
  Future<String?> getCachedImagePath(String url) async {
    try {
      final db = await database;
      
      final List<Map<String, dynamic>> result = await db.query(
        _tableName,
        columns: ['localPath'],
        where: 'url = ?',
        whereArgs: [url],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        return result.first['localPath'] as String?;
      }
    } catch (e) {
      print('ImageCacheService: Error getting cached image path: $e');
    }
    
    return null;
  }
  
  // Cargar imagen de assets
  Future<File?> loadAssetImage(String assetPath, String uniqueId) async {
    try {
      // Generate unique identifier for this asset
      final hash = sha1.convert(utf8.encode(assetPath + uniqueId)).toString();
      
      // Check if already in cache
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _tableName,
        columns: ['localPath'],
        where: 'url = ?',
        whereArgs: ['asset://$assetPath'],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final path = result.first['localPath'] as String?;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            return file;
          }
        }
      }
      
      // Load the asset
      final ByteData data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      
      // Get cache directory
      final cacheDir = await _getCacheDirectory();
      final file = File('${cacheDir.path}/$hash.jpg');
      
      // Write to file
      await file.writeAsBytes(bytes);
      
      // Save to database
      await db.insert(
        _tableName,
        {
          'url': 'asset://$assetPath',
          'localPath': file.path,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
          'fileSize': bytes.length
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      return file;
    } catch (e) {
      print('ImageCacheService: Error loading asset image: $e');
      return null;
    }
  }
  
  // Limpiar caché de imágenes antiguas (llamar periódicamente)
  Future<void> cleanOldCache({int maxAgeDays = 30, int maxSizeMB = 100}) async {
    try {
      final db = await database;
      final cutoffTime = DateTime.now().subtract(Duration(days: maxAgeDays)).millisecondsSinceEpoch;
      
      // Get current cache size
      final sizeResult = await db.rawQuery('SELECT SUM(fileSize) as totalSize FROM $_tableName');
      final totalSize = sizeResult.first['totalSize'] as int? ?? 0;
      final totalSizeMB = totalSize / (1024 * 1024);
      
      // If cache is smaller than the limit and not too old, skip cleaning
      if (totalSizeMB < maxSizeMB && cutoffTime > 0) {
        return;
      }
      
      // Get entries ordered by last updated (oldest first)
      final oldEntries = await db.query(
        _tableName,
        orderBy: 'lastUpdated ASC',
      );
      
      int deletedCount = 0;
      int freedSpaceBytes = 0;
      
      // Start deleting from oldest until we're under the limit
      for (final entry in oldEntries) {
        // Skip if this would bring us under the size/age threshold
        final entryAge = entry['lastUpdated'] as int? ?? 0;
        if (totalSizeMB - (freedSpaceBytes / (1024 * 1024)) < maxSizeMB && 
            entryAge > cutoffTime && deletedCount > 0) {
          break;
        }
        
        final localPath = entry['localPath'] as String;
        final url = entry['url'] as String;
        final fileSize = entry['fileSize'] as int? ?? 0;
        
        try {
          final file = File(localPath);
          if (await file.exists()) {
            await file.delete();
          }
          
          // Remove from database and memory cache
          await db.delete(
            _tableName,
            where: 'url = ?',
            whereArgs: [url],
          );
          
          _memoryCache.remove(url);
          
          deletedCount++;
          freedSpaceBytes += fileSize;
        } catch (e) {
          print('ImageCacheService: Error deleting cached file: $e');
        }
      }
      
      print('ImageCacheService: Cleaned $deletedCount cached images, freed ${(freedSpaceBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
    } catch (e) {
      print('ImageCacheService: Error cleaning old cache: $e');
    }
  }
  
  // Precargar una lista de imágenes para uso offline
  Future<void> precacheImages(List<String> urls) async {
    if (urls.isEmpty) return;
    
    print('ImageCacheService: Precaching ${urls.length} images');
    
    // Filter out URLs that are already cached
    final List<String> urlsToCache = [];
    for (final url in urls) {
      if (!(await hasCachedImage(url))) {
        urlsToCache.add(url);
      }
    }
    
    if (urlsToCache.isEmpty) {
      print('ImageCacheService: All images already cached');
      return;
    }
    
    print('ImageCacheService: Downloading ${urlsToCache.length} new images');
    
    // Download each image
    for (final url in urlsToCache) {
      try {
        await getImageFile(url);
      } catch (e) {
        print('ImageCacheService: Error precaching image $url: $e');
      }
    }
  }
  
  // Widget para mostrar imagen optimizada
  Widget getOptimizedImageWidget(String? url, {
    double width = 40,
    double height = 40,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    String defaultAsset = 'assets/images/Avatar.png',
    bool circle = false,
  }) {
    if (url == null || url.isEmpty) {
      return _wrapInCircleIfNeeded(
        Image.asset(
          defaultAsset,
          width: width,
          height: height,
          fit: fit,
        ),
        circle
      );
    }
    
    return FutureBuilder<ImageProvider>(
      future: getImageProvider(url, placeholder: AssetImage(defaultAsset)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? Center(child: CupertinoActivityIndicator());
        }
        
        if (!snapshot.hasData || snapshot.hasError) {
          return errorWidget ?? _wrapInCircleIfNeeded(
            Image.asset(
              defaultAsset,
              width: width,
              height: height,
              fit: fit,
            ),
            circle
          );
        }
        
        return _wrapInCircleIfNeeded(
          Image(
            image: snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return errorWidget ?? Image.asset(
                defaultAsset,
                width: width,
                height: height,
                fit: fit,
              );
            },
          ),
          circle
        );
      },
    );
  }
  
  // Helper para envolver en círculo si es necesario
  Widget _wrapInCircleIfNeeded(Widget child, bool circle) {
    if (!circle) return child;
    
    return ClipOval(child: child);
  }
}