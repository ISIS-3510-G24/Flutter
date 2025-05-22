import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageStorageService {
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

  static const String _queueImagesFolder = 'queue_images';
  Directory? _queueDirectory;

  /// Initialize the storage service
  Future<void> initialize() async {
    debugPrint('🖼️ Initializing ImageStorageService');
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      _queueDirectory = Directory('${appDocDir.path}/$_queueImagesFolder');
      
      // Create directory if it doesn't exist
      if (!await _queueDirectory!.exists()) {
        await _queueDirectory!.create(recursive: true);
        debugPrint('📁 Created queue images directory: ${_queueDirectory!.path}');
      }
      
      debugPrint('✅ ImageStorageService initialized: ${_queueDirectory!.path}');
    } catch (e) {
      debugPrint('🚨 Error initializing ImageStorageService: $e');
    }
  }

  /// Save an image from temporary path to permanent storage
  Future<String?> saveImageToQueue(String tempImagePath) async {
    try {
      debugPrint('💾 Saving image to permanent storage: $tempImagePath');
      
      // Ensure directory exists
      if (_queueDirectory == null) {
        await initialize();
      }
      
      if (_queueDirectory == null) {
        debugPrint('🚨 Queue directory not available');
        return null;
      }

      // Check if source file exists
      final sourceFile = File(tempImagePath);
      if (!await sourceFile.exists()) {
        debugPrint('🚨 Source image file does not exist: $tempImagePath');
        return null;
      }

      // Generate unique filename
      final uuid = const Uuid().v4();
      final extension = tempImagePath.split('.').last.toLowerCase();
      final fileName = '${uuid}.$extension';
      final permanentPath = '${_queueDirectory!.path}/$fileName';

      // Copy file to permanent location
      final permanentFile = await sourceFile.copy(permanentPath);
      
      debugPrint('✅ Image saved permanently: $permanentPath');
      debugPrint('📏 File size: ${await permanentFile.length()} bytes');
      
      return permanentPath;
    } catch (e) {
      debugPrint('🚨 Error saving image to queue: $e');
      return null;
    }
  }

  /// Save multiple images to permanent storage
  Future<List<String>> saveImagesToQueue(List<String> tempImagePaths) async {
    debugPrint('💾 Saving ${tempImagePaths.length} images to permanent storage');
    
    final permanentPaths = <String>[];
    
    for (final tempPath in tempImagePaths) {
      final permanentPath = await saveImageToQueue(tempPath);
      if (permanentPath != null) {
        permanentPaths.add(permanentPath);
      }
    }
    
    debugPrint('✅ Saved ${permanentPaths.length}/${tempImagePaths.length} images permanently');
    return permanentPaths;
  }

  /// Delete an image from permanent storage
  Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ Deleted image: $imagePath');
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
    for (final path in imagePaths) {
      if (await deleteImage(path)) {
        deletedCount++;
      }
    }
    
    debugPrint('✅ Deleted $deletedCount/${imagePaths.length} images');
  }

  /// Check if an image file exists
  Future<bool> imageExists(String imagePath) async {
    try {
      final file = File(imagePath);
      return await file.exists();
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
        return await file.length();
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
      debugPrint('🧹 Cleaning up orphaned images in queue directory');
      
      if (_queueDirectory == null) {
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
      debugPrint('🔗 ${referencedImagePaths.length} images are referenced by queue items');

      // Find orphaned files
      final orphanedFiles = imageFiles.where((file) => 
          !referencedImagePaths.contains(file.path)).toList();

      debugPrint('🗑️ Found ${orphanedFiles.length} orphaned images to delete');

      // Delete orphaned files
      int deletedCount = 0;
      for (final file in orphanedFiles) {
        try {
          await file.delete();
          deletedCount++;
          debugPrint('🗑️ Deleted orphaned image: ${file.path}');
        } catch (e) {
          debugPrint('🚨 Error deleting orphaned image ${file.path}: $e');
        }
      }

      debugPrint('✅ Cleanup complete: deleted $deletedCount orphaned images');
    } catch (e) {
      debugPrint('🚨 Error during orphaned images cleanup: $e');
    }
  }

  /// Get total size of all queue images
  Future<int> getTotalQueueImagesSize() async {
    try {
      if (_queueDirectory == null || !await _queueDirectory!.exists()) {
        return 0;
      }

      final allFiles = await _queueDirectory!.list().toList();
      final imageFiles = allFiles
          .whereType<File>()
          .where((file) => _isImageFile(file.path));

      int totalSize = 0;
      for (final file in imageFiles) {
        totalSize += (await file.length()).toInt();
      }

      return totalSize;
    } catch (e) {
      debugPrint('🚨 Error calculating total queue images size: $e');
      return 0;
    }
  }

  /// Check if a file is an image based on extension
  bool _isImageFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  /// Get queue directory path (for debugging)
  String? get queueDirectoryPath => _queueDirectory?.path;
}