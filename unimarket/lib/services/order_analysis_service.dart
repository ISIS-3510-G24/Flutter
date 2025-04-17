import 'package:cloud_firestore/cloud_firestore.dart';

class OrderAnalysisService {
  // Analizar las órdenes y agruparlas por hora
  Future<Map<int, int>> analyzeOrderActivity() async {
    final ordersSnapshot = await FirebaseFirestore.instance.collection('orders').get();
    final orders = ordersSnapshot.docs;

    final Map<int, int> ordersByHour = {};

    for (var order in orders) {
      final orderDate = (order['orderDate'] as Timestamp).toDate();
      final hour = orderDate.hour;

      if (ordersByHour.containsKey(hour)) {
        ordersByHour[hour] = ordersByHour[hour]! + 1;
      } else {
        ordersByHour[hour] = 1;
      }
    }

    return ordersByHour;
  }

  // Encontrar las horas pico
  Future<List<int>> findPeakHours() async {
    final ordersByHour = await analyzeOrderActivity();

    // Ordenar las horas por cantidad de órdenes
    final sortedHours = ordersByHour.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Retornar las 3 horas con mayor actividad
    return sortedHours.take(3).map((entry) => entry.key).toList();
  }
}