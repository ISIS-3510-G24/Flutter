// lib/viewmodels/camera_view_model.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:unimarket/services/lidar_camera_service.dart';
import 'package:unimarket/services/firebase_storage_service.dart';

/// ViewModel for camera screen operations
/// Follows MVVM pattern to separate business logic from UI
class CameraViewModel with ChangeNotifier {
  final LiDARCameraService _cameraService = LiDARCameraService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  
  bool _isInitialized = false;
  bool _isLoading = false;
  File? _capturedImage;
  String _errorMessage = '';
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  File? get capturedImage => _capturedImage;
  String get errorMessage => _errorMessage;
  
  // Connect to service notifiers
  ValueNotifier<double?> get distanceNotifier => _cameraService.distanceNotifier;
  ValueNotifier<double> get lightLevelNotifier => _cameraService.lightLevelNotifier;
  ValueNotifier<String> get feedbackNotifier => _cameraService.feedbackNotifier;
  
  /// Initialize camera and services
  Future<void> initialize() async {
    try {
      _setLoading(true);
      
      final initialized = await _cameraService.initialize();
      _isInitialized = initialized;
      
      if (!initialized) {
        _errorMessage = 'Failed to initialize camera';
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      _isInitialized = false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Initialize ARKit for LiDAR
  void initializeARKit(ARKitController controller) {
    _cameraService.initializeARKit(controller);
  }
  
  /// Take picture with camera
  Future<void> takePicture() async {
    try {
      _setLoading(true);
      
      final image = await _cameraService.takePicture();
      if (image != null) {
        _capturedImage = image;
      } else {
        _errorMessage = 'Failed to capture image';
      }
    } catch (e) {
      _errorMessage = 'Error taking picture: $e';
    } finally {
      _setLoading(false);
    }
  }
  
  /// Pick image from gallery
  Future<void> pickFromGallery() async {
    try {
      _setLoading(true);
      
      final image = await _cameraService.pickFromGallery();
      if (image != null) {
        _capturedImage = image;
      }
    } catch (e) {
      _errorMessage = 'Error picking image: $e';
    } finally {
      _setLoading(false);
    }
  }
  
  /// Upload captured image to Firebase storage
  Future<String?> uploadImage() async {
    if (_capturedImage == null) {
      _errorMessage = 'No image to upload';
      return null;
    }
    
    try {
      _setLoading(true);
      
      // Upload to Firebase Storage
      final downloadUrl = await _storageService.uploadProductImage(_capturedImage!);
      return downloadUrl;
    } catch (e) {
      _errorMessage = 'Error uploading image: $e';
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Reset state and discard captured image
  void resetImage() {
    _capturedImage = null;
    notifyListeners();
  }
  
  /// Set loading state and notify listeners
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Clean up resources
  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}