import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class ImageStorageService {
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

  static const String _queueImagesFolder = 'queue_images';
  Directory? _queueDirectory;
  bool _isInitialized = false;

  /// Initialize the storage service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🖼️ ImageStorageService already initialized');
      return;
    }
    
    debugPrint('🖼️ Initializing ImageStorageService');
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      _queueDirectory = Directory('${appDocDir.path}/$_queueImagesFolder');
      
      // Create directory if it doesn't exist
      if (!await _queueDirectory!.exists()) {
        await _queueDirectory!.create(recursive: true);
        debugPrint('📁 Created queue images directory: ${_queueDirectory!.path}');
      }
      
      _isInitialized = true;
      debugPrint('✅ ImageStorageService initialized: ${_queueDirectory!.path}');
    } catch (e) {
      debugPrint('🚨 Error initializing ImageStorageService: $e');
      _isInitialized = false;
    }
  }

  /// Save an image from temporary path to permanent storage
  Future<String?> saveImageToQueue(String tempImagePath) async {
    try {
      debugPrint('💾 Saving image to permanent storage: $tempImagePath');
      
      // Ensure initialization
      if (!_isInitialized) {
        await initialize();
      }
      
      if (_queueDirectory == null) {
        debugPrint('🚨 Queue directory not available after initialization');
        return null;
      }

      // Check if source file exists
      final sourceFile = File(tempImagePath);
      if (!await sourceFile.exists()) {
        debugPrint('🚨 Source image file does not exist: $tempImagePath');
        return null;
      }

      // Get file info
      final fileSize = await sourceFile.length();
      debugPrint('📏 Source file size: ${(fileSize / 1024).toInt()} KB');

      // Generate unique filename preserving extension
      final uuid = const Uuid().v4();
      final originalExtension = path.extension(tempImagePath).toLowerCase();
      final cleanExtension = originalExtension.isEmpty ? '.jpg' : originalExtension;
      final fileName = '${uuid}$cleanExtension';
      final permanentPath = path.join(_queueDirectory!.path, fileName);

      debugPrint('🎯 Target permanent path: $permanentPath');

      // Copy file to permanent location
      final permanentFile = await sourceFile.copy(permanentPath);
      
      // Verify the copy was successful
      if (await permanentFile.exists()) {
        final newFileSize = await permanentFile.length();
        if (newFileSize == fileSize) {
          debugPrint('✅ Image saved permanently: $permanentPath');
          debugPrint('📏 Verified file size: ${(newFileSize / 1024).toInt()} KB');
          return permanentPath;
        } else {
          debugPrint('🚨 File size mismatch after copy. Original: $fileSize, New: $newFileSize');
          // Clean up the failed copy
          await permanentFile.delete();
          return null;
        }
      } else {
        debugPrint('🚨 Permanent file does not exist after copy operation');
        return null;
      }
    } catch (e) {
      debugPrint('🚨 Error saving image to queue: $e');
      return null;
    }
  }

  /// Save multiple images to permanent storage
  Future<List<String>> saveImagesToQueue(List<String> tempImagePaths) async {
    debugPrint('💾 Saving ${tempImagePaths.length} images to permanent storage');
    
    final permanentPaths = <String>[];
    
    for (int i = 0; i < tempImagePaths.length; i++) {
      final tempPath = tempImagePaths[i];
      debugPrint('💾 Processing image ${i + 1}/${tempImagePaths.length}: $tempPath');
      
      final permanentPath = await saveImageToQueue(tempPath);
      if (permanentPath != null) {
        permanentPaths.add(permanentPath);
        debugPrint('✅ Image ${i + 1} saved successfully');
      } else {
        debugPrint('❌ Failed to save image ${i + 1}');
      }
    }
    
    debugPrint('📊 Final result: ${permanentPaths.length}/${tempImagePaths.length} images saved permanently');
    return permanentPaths;
  }

  /// Delete an image from permanent storage
  Future<bool> deleteImage(String imagePath) async {
    try {
      debugPrint('🗑️ Attempting to delete image: $imagePath');
      
      final file = File(imagePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        await file.delete();
        debugPrint('✅ Deleted image: $imagePath (${(fileSize / 1024).toInt()} KB)');
        return true;
      } else {
        debugPrint('⚠️ Image file not found for deletion: $imagePath');
        return false;
      }
    } catch (e) {
      debugPrint('🚨 Error deleting image: $e');
      return false;
    }
  }

  /// Delete multiple images from permanent storage
  Future<void> deleteImages(List<String> imagePaths) async {
    debugPrint('🗑️ Deleting ${imagePaths.length} images from permanent storage');
    
    int deletedCount = 0;
    for (int i = 0; i < imagePaths.length; i++) {
      final path = imagePaths[i];
      debugPrint('🗑️ Deleting image ${i + 1}/${imagePaths.length}: $path');
      
      if (await deleteImage(path)) {
        deletedCount++;
      }
    }
    
    debugPrint('📊 Deletion complete: $deletedCount/${imagePaths.length} images deleted');
  }

  /// Check if an image file exists
  Future<bool> imageExists(String imagePath) async {
    try {
      final file = File(imagePath);
      final exists = await file.exists();
      debugPrint('🔍 Image exists check: $imagePath = $exists');
      return exists;
    } catch (e) {
      debugPrint('🚨 Error checking image existence: $e');
      return false;
    }
  }

  /// Get the size of an image file
  Future<int> getImageSize(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        final size = await file.length();
        debugPrint('📏 Image size: $imagePath = ${(size / 1024).toInt()} KB');
        return size;
      }
      return 0;
    } catch (e) {
      debugPrint('🚨 Error getting image size: $e');
      return 0;
    }
  }

  /// Clean up orphaned images (images not referenced by any queue item)
  Future<void> cleanupOrphanedImages(List<String> referencedImagePaths) async {
    try {
      debugPrint('🧹 Starting orphaned images cleanup');
      debugPrint('🔗 Referenced image paths: ${referencedImagePaths.length}');
      
      if (!_isInitialized) {
        await initialize();
      }
      
      if (_queueDirectory == null || !await _queueDirectory!.exists()) {
        debugPrint('📁 Queue directory does not exist, skipping cleanup');
        return;
      }

      // Get all image files in directory
      final allFiles = await _queueDirectory!.list().toList();
      final imageFiles = allFiles
          .whereType<File>()
          .where((file) => _isImageFile(file.path))
          .toList();

      debugPrint('📁 Found ${imageFiles.length} image files in queue directory');

      // Find orphaned files (files not in the referenced list)
      final orphanedFiles = <File>[];
      for (final file in imageFiles) {
        final isReferenced = referencedImagePaths.contains(file.path);
        if (!isReferenced) {
          orphanedFiles.add(file);
          debugPrint('🗑️ Found orphaned image: ${file.path}');
        }
      }

      debugPrint('📊 Found ${orphanedFiles.length} orphaned images to delete');

      // Delete orphaned files
      int deletedCount = 0;
      int totalSizeDeleted = 0;
      
      for (final file in orphanedFiles) {
        try {
          final fileSize = await file.length();
          await file.delete();
          deletedCount++;
          totalSizeDeleted += fileSize;
          debugPrint('✅ Deleted orphaned image: ${file.path} (${(fileSize / 1024).toInt()} KB)');
        } catch (e) {
          debugPrint('🚨 Error deleting orphaned image ${file.path}: $e');
        }
      }

      debugPrint('📊 Cleanup complete: deleted $deletedCount orphaned images');
      debugPrint('💾 Total space freed: ${(totalSizeDeleted / (1024 * 1024)).toStringAsFixed(2)} MB');
    } catch (e) {
      debugPrint('🚨 Error during orphaned images cleanup: $e');
    }
  }

  /// Get total size of all queue images
  Future<int> getTotalQueueImagesSize() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      if (_queueDirectory == null || !await _queueDirectory!.exists()) {
        return 0;
      }

      final allFiles = await _queueDirectory!.list().toList();
      final imageFiles = allFiles
          .whereType<File>()
          .where((file) => _isImageFile(file.path));

      int totalSize = 0;
      int fileCount = 0;
      
      for (final file in imageFiles) {
        try {
          final fileSize = await file.length();
          totalSize += fileSize;
          fileCount++;
        } catch (e) {
          debugPrint('🚨 Error getting size for file ${file.path}: $e');
        }
      }

      debugPrint('📊 Total queue storage: $fileCount files, ${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB');
      return totalSize;
    } catch (e) {
      debugPrint('🚨 Error calculating total queue images size: $e');
      return 0;
    }
  }

  /// Get detailed storage statistics
  Future<Map<String, dynamic>> getDetailedStorageStats() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      if (_queueDirectory == null || !await _queueDirectory!.exists()) {
        return {
          'totalFiles': 0,
          'totalSizeBytes': 0,
          'totalSizeMB': 0.0,
          'directoryExists': false,
          'directoryPath': 'N/A',
        };
      }

      final allFiles = await _queueDirectory!.list().toList();
      final imageFiles = allFiles
          .whereType<File>()
          .where((file) => _isImageFile(file.path))
          .toList();

      int totalSize = 0;
      for (final file in imageFiles) {
        try {
          totalSize += await file.length();
        } catch (e) {
          debugPrint('Error getting size for ${file.path}: $e');
        }
      }

      return {
        'totalFiles': imageFiles.length,
        'totalSizeBytes': totalSize,
        'totalSizeMB': totalSize / (1024 * 1024),
        'directoryExists': true,
        'directoryPath': _queueDirectory!.path,
      };
    } catch (e) {
      debugPrint('🚨 Error getting detailed storage stats: $e');
      return {
        'totalFiles': 0,
        'totalSizeBytes': 0,
        'totalSizeMB': 0.0,
        'directoryExists': false,
        'directoryPath': 'Error',
        'error': e.toString(),
      };
    }
  }

  /// Check if a file is an image based on extension
  bool _isImageFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  /// Get queue directory path (for debugging)
  String? get queueDirectoryPath => _queueDirectory?.path;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Verify queue directory integrity
  Future<bool> verifyDirectoryIntegrity() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      if (_queueDirectory == null) {
        debugPrint('🚨 Queue directory is null');
        return false;
      }
      
      final exists = await _queueDirectory!.exists();
      if (!exists) {
        debugPrint('🚨 Queue directory does not exist: ${_queueDirectory!.path}');
        return false;
      }
      
      // Try to list contents to verify we can access the directory
      final contents = await _queueDirectory!.list().toList();
      debugPrint('✅ Queue directory integrity verified: ${contents.length} items');
      return true;
    } catch (e) {
      debugPrint('🚨 Error verifying directory integrity: $e');
      return false;
    }
  }
}