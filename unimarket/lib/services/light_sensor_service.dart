import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';

class LightSensorService {
  // Notificadores para UI reactiva
  final ValueNotifier<double> lightLevelNotifier = ValueNotifier<double>(0.5);
  final ValueNotifier<String> feedbackNotifier = ValueNotifier<String>("Analizando luz...");
  
  // Variables de control
  bool _isProcessing = false;
  
  // Buffer para suavizado
  final List<double> _lightBuffer = [];
  final int _bufferSize = 5; // Aumentado para mayor suavizado
  
  // Método para procesar una imagen de CameraImage
  void processCameraImage(CameraImage image) {
    if (_isProcessing) return;
    
    try {
      _isProcessing = true;
      
      if (image.planes.isEmpty) {
        print("❌ Sin planos de imagen");
        return;
      }
      
      // Calcular brillo a partir del plano de luminancia
      final plane = image.planes[0];
      if (plane.bytes.isEmpty) {
        print("❌ Bytes de imagen vacíos");
        return;
      }
      
      int total = 0;
      int samples = 0;
      
      // Usar una estrategia de muestreo más eficiente
      // Tomar píxeles del centro de la imagen donde suele estar el sujeto
      final int width = image.width;
      final int height = image.height;
      final int stride = plane.bytesPerRow;
      
      // Región central (25% del centro de la imagen)
      final int startX = width ~/ 4;
      final int endX = width - startX;
      final int startY = height ~/ 4;
      final int endY = height - startY;
      
      // Muestreo con saltos para eficiencia
      for (int y = startY; y < endY; y += 10) {
        for (int x = startX; x < endX; x += 10) {
          final int index = y * stride + x;
          if (index < plane.bytes.length) {
            total += plane.bytes[index];
            samples++;
          }
        }
      }
      
      if (samples == 0) {
        print("⚠️ Sin muestras válidas");
        return;
      }
      
      // Calcular brillo normalizado (0-1)
      final double brightness = total / (samples * 255);
      
      // Imprimir muestras para diagnóstico
      print("📊 Muestras: $samples, Brillo: ${(brightness * 100).toStringAsFixed(1)}%");
      
      // Añadir al buffer para suavizado
      _lightBuffer.add(brightness);
      if (_lightBuffer.length > _bufferSize) {
        _lightBuffer.removeAt(0);
      }
      
      // Calcular promedio suavizado
      final smoothedBrightness = _lightBuffer.reduce((a, b) => a + b) / _lightBuffer.length;
      
      // Actualizar notificadores con un valor definido verificando que no sea NaN
      if (!smoothedBrightness.isNaN) {
        lightLevelNotifier.value = smoothedBrightness;
        _updateFeedback(smoothedBrightness);
      } else {
        print("⚠️ Valor NaN detectado");
      }
    } catch (e) {
      print("❌ Error al procesar luz: $e");
    } finally {
      _isProcessing = false;
    }
  }
  
  // Actualizar feedback según nivel de luz
  void _updateFeedback(double brightness) {
    String newFeedback;
    
    if (brightness < 0.2) {
      newFeedback = "Ambiente muy oscuro, acércate a una fuente de luz";
    } else if (brightness < 0.35) {
      newFeedback = "Poca luz, mejora la iluminación";
    } else if (brightness > 0.8) {
      newFeedback = "Demasiada luz, evita luz directa";
    } else if (brightness > 0.65) {
      newFeedback = "Luz alta, considera reducir la iluminación";
    } else {
      newFeedback = "Iluminación ideal ✓";
    }
    
    // Solo actualizar si hay cambio para evitar reconstrucciones de UI innecesarias
    if (feedbackNotifier.value != newFeedback) {
      print("💡 Actualizando feedback: $newFeedback");
      feedbackNotifier.value = newFeedback;
    }
  }
  
  // Obtener color según nivel de luz
  Color getLightLevelColor(double lightLevel) {
    if (lightLevel < 0.2) {
      return CupertinoColors.systemRed; // Muy oscuro
    } else if (lightLevel < 0.35) {
      return CupertinoColors.systemOrange; // Oscuro
    } else if (lightLevel > 0.8) {
      return CupertinoColors.systemRed; // Muy brillante
    } else if (lightLevel > 0.65) {
      return CupertinoColors.systemYellow; // Brillante
    } else {
      return CupertinoColors.activeGreen; // Ideal
    }
  }
  
  // Liberar recursos
  void dispose() {
    lightLevelNotifier.dispose();
    feedbackNotifier.dispose();
    _lightBuffer.clear();
    _isProcessing = false;
    
    print("🗑️ LightSensorService: Recursos liberados");
  }
}