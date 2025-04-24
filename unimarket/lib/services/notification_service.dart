import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  final String _serverKey = 'YOUR_SERVER_KEY'; 

  // Enviar notificación promocional
  Future<void> sendPromotionalNotification(String title, String body) async {
    final response = await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$_serverKey',
      },
      body: jsonEncode({
        'to': '/topics/promotions', // Envía a un topic específico
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'type': 'promotion',
        },
      }),
    );

    if (response.statusCode == 200) {
      print("Notification sent successfully");
    } else {
      print("Failed to send notification: ${response.body}");
    }
  }
}