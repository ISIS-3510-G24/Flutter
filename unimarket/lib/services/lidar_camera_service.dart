// lib/services/camera/lidar_camera_service.dart

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Service responsible for camera operations, LiDAR sensing and lighting detection
/// Following the Repository pattern - this abstracts the device sensors and camera APIs
class LiDARCameraService {
  CameraController? _cameraController;
  ARKitController? _arKitController;
  bool _hasLiDAR = false;
  bool _isCameraInitialized = false;
  
  // Streams for real-time feedback
  final ValueNotifier<double?> distanceNotifier = ValueNotifier<double?>(null);
  final ValueNotifier<double> lightLevelNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> feedbackNotifier = ValueNotifier<String>("");
  
  /// Initialize the camera and check for LiDAR availability
  Future<bool> initialize() async {
    try {
      // Check if device supports LiDAR
      _hasLiDAR = await _checkLiDARSupport();
      
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        feedbackNotifier.value = "No cameras found";
        return false;
      }
      
      // Use the back camera
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      
      // Initialize camera with optimal resolution
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS 
            ? ImageFormatGroup.bgra8888 
            : ImageFormatGroup.yuv420,
      );
      
      await _cameraController!.initialize();
      
      // Start image stream for light detection
      await _cameraController!.startImageStream(_processCameraImage);
      
      _isCameraInitialized = true;
      feedbackNotifier.value = "Camera initialized";
      
      return true;
    } catch (e) {
      feedbackNotifier.value = "Error initializing camera: $e";
      return false;
    }
  }
  
  /// Check if the device supports LiDAR
  Future<bool> _checkLiDARSupport() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      
      // LiDAR is available on iPhone 12 Pro and later
      final String model = iosInfo.model;
      
      // LiDAR is available on:
      // - iPhone 12 Pro, iPhone 12 Pro Max 
      // - iPhone 13 Pro, iPhone 13 Pro Max
      // - iPhone 14 Pro, iPhone 14 Pro Max
      // - iPhone 15 Pro, iPhone 15 Pro Max
      // - iPad Pro 2020 and later
      
      final bool hasLiDAR = model.contains('iPhone 12 Pro') ||
                            model.contains('iPhone 13 Pro') ||
                            model.contains('iPhone 14 Pro') ||
                            model.contains('iPhone 15 Pro') ||
                            (model.contains('iPad Pro') && 
                             int.parse(model.split(' ').last) >= 2020);
      
      feedbackNotifier.value = hasLiDAR 
          ? "LiDAR available" 
          : "LiDAR not available";
      
      return hasLiDAR;
    } catch (e) {
      feedbackNotifier.value = "Error checking LiDAR support: $e";
      return false;
    }
  }
  
  /// Initialize ARKit for LiDAR distance measurements
  Future<void> initializeARKit(ARKitController controller) async {
    if (!_hasLiDAR) return;
    
    _arKitController = controller;
    
    controller.onUpdateNodeForAnchor = (ARKitAnchor anchor) {
      if (anchor is ARKitPlaneAnchor) {
        _updateDistanceFeedback(anchor);
      }
    };
  }
  
  /// Update distance feedback based on LiDAR data
  void _updateDistanceFeedback(ARKitPlaneAnchor anchor) {
    // Distance in meters
    final double distance = anchor.transform.getColumn(3).z;
    distanceNotifier.value = distance;
    
    // Provide feedback based on distance
    if (distance < 0.3) {
      feedbackNotifier.value = "Too close to object";
    } else if (distance > 1.5) {
      feedbackNotifier.value = "Move closer to object";
    } else {
      feedbackNotifier.value = "Good distance";
    }
  }
  
  /// Process camera image to detect light level
  void _processCameraImage(CameraImage image) {
    if (image.planes.isEmpty) return;
    
    // Calculate average brightness from the Y plane (luminance)
    final plane = image.planes[0];
    int totalLuminance = 0;
    
    // Sample every 10th pixel for efficiency
    for (int i = 0; i < plane.bytes.length; i += 10) {
      totalLuminance += plane.bytes[i];
    }
    
    // Average brightness level (0-255)
    final int pixelCount = plane.bytes.length ~/ 10;
    final double averageLuminance = totalLuminance / pixelCount;
    
    // Normalize to 0-1 range
    final double normalizedLightLevel = averageLuminance / 255.0;
    lightLevelNotifier.value = normalizedLightLevel;
    
    // Update light feedback (don't override distance feedback if it exists)
    if (distanceNotifier.value == null) {
      if (normalizedLightLevel < 0.2) {
        feedbackNotifier.value = "Too dark, add more light";
      } else if (normalizedLightLevel > 0.8) {
        feedbackNotifier.value = "Too bright, reduce light";
      } else {
        feedbackNotifier.value = "Good lighting";
      }
    }
  }
  
  /// Take a picture and return the file
  Future<File?> takePicture() async {
    if (!_isCameraInitialized || _cameraController == null) {
      feedbackNotifier.value = "Camera not initialized";
      return null;
    }
    
    try {
      final XFile photo = await _cameraController!.takePicture();
      
      // Create a more organized file path
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(appDir.path, fileName);
      
      // Copy the file to the new path
      final File savedImage = File(photo.path);
      final File newFile = await savedImage.copy(filePath);
      
      return newFile;
    } catch (e) {
      feedbackNotifier.value = "Error taking picture: $e";
      return null;
    }
  }
  
  /// Pick an image from the gallery
  Future<File?> pickFromGallery() async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery, 
        imageQuality: 90,
      );
      
      if (pickedFile == null) return null;
      
      return File(pickedFile.path);
    } catch (e) {
      feedbackNotifier.value = "Error picking image: $e";
      return null;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _cameraController?.dispose();
    _arKitController?.dispose();
    distanceNotifier.dispose();
    lightLevelNotifier.dispose();
    feedbackNotifier.dispose();
  }
}