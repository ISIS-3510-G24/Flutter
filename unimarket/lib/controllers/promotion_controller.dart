import 'package:unimarket/services/order_analysis_service.dart';
import 'package:unimarket/services/notification_service.dart';

class PromotionController {
  final OrderAnalysisService _orderAnalysisService = OrderAnalysisService();
  final NotificationService _notificationService = NotificationService();

  // Analizar órdenes y enviar promociones
  Future<void> analyzeAndSendPromotions() async {
    final peakHours = await _orderAnalysisService.findPeakHours();

    if (peakHours.isNotEmpty) {
      final peakHour = peakHours.first; // Tomar la hora con mayor actividad
      final nextHour = (peakHour + 1) % 24;

      final title = "Last Chance!";
      final body = "Products are flying off the shelves! Complete your payment before it's too late!";

      await _notificationService.sendPromotionalNotification(title, body);
    } else {
      print("No peak hours found.");
    }
  }
}