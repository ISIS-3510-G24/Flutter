// lib/services/sensor/sensor_service.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Service class to handle sensor data processing (LiDAR, light)
/// This follows a Service Layer pattern to isolate sensor logic
class SensorService {
  // ValueNotifiers to expose sensor data to UI
  final ValueNotifier<double?> distanceNotifier = ValueNotifier<double?>(null);
  final ValueNotifier<double> lightLevelNotifier = ValueNotifier<double>(0.5);
  final ValueNotifier<String> feedbackNotifier = ValueNotifier<String>("");
  
  // Status flags
  bool _hasLiDAR = false;
  
  /// Check if the device supports LiDAR
  Future<bool> checkLiDARSupport() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      
      // LiDAR is available on iPhone 12 Pro and later Pro models
      final String model = iosInfo.model;
      
      // LiDAR is available on:
      // - iPhone 12 Pro, iPhone 12 Pro Max 
      // - iPhone 13 Pro, iPhone 13 Pro Max
      // - iPhone 14 Pro, iPhone 14 Pro Max
      // - iPhone 15 Pro, iPhone 15 Pro Max
      // - iPad Pro 2020 and later
      
      _hasLiDAR = model.contains('iPhone 12 Pro') ||
                  model.contains('iPhone 13 Pro') ||
                  model.contains('iPhone 14 Pro') ||
                  model.contains('iPhone 15 Pro') ||
                  (model.contains('iPad Pro') && 
                   int.parse(model.split(' ').last) >= 2020);
      
      feedbackNotifier.value = _hasLiDAR 
          ? "LiDAR sensor available" 
          : "LiDAR not available";
      
      return _hasLiDAR;
    } catch (e) {
      print("Error checking LiDAR support: $e");
      feedbackNotifier.value = "Error checking LiDAR";
      return false;
    }
  }
  
  /// Process camera image to analyze light levels
  void processCameraImage(CameraImage image) {
    if (image.planes.isEmpty) return;
    
    try {
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
    } catch (e) {
      print("Error processing camera image: $e");
    }
  }
  
  /// Process ARKit anchor to extract distance info from LiDAR
  void processARKitAnchor(ARKitAnchor anchor) {
    if (anchor is ARKitPlaneAnchor) {
      try {
        // Distance in meters from camera to detected plane
        final double distance = anchor.transform.getColumn(3).z;
        distanceNotifier.value = distance;
        
        // Provide feedback based on distance
        if (distance < 0.3) {
          feedbackNotifier.value = "Too close to object";
        } else if (distance > 1.5) {
          feedbackNotifier.value = "Move closer to object";
        } else {
          feedbackNotifier.value = "Good distance for photo";
        }
      } catch (e) {
        print("Error processing ARKit anchor: $e");
      }
    }
  }
  
  /// Get appropriate color for light level feedback
  Color getLightLevelColor(double lightLevel) {
    if (lightLevel < 0.2) {
      return const Color(0xFFFF3B30); // Red
    } else if (lightLevel > 0.8) {
      return const Color(0xFFFF9500); // Orange
    } else {
      return const Color(0xFF34C759); // Green
    }
  }
  
  /// Get appropriate color for distance feedback
  Color getDistanceColor(double? distance) {
    if (distance == null) {
      return const Color(0xFF8E8E93); // Gray
    } else if (distance < 0.3) {
      return const Color(0xFFFF3B30); // Red
    } else if (distance > 1.5) {
      return const Color(0xFFFF9500); // Orange
    } else {
      return const Color(0xFF34C759); // Green
    }
  }
  
  /// Clean up resources
  void dispose() {
    distanceNotifier.dispose();
    lightLevelNotifier.dispose();
    feedbackNotifier.dispose();
  }
}