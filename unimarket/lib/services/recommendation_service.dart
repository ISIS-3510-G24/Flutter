import 'package:flutter/foundation.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/recommendation_model.dart';

Future<List<String>> generateRecommendations(List<Map<String, dynamic>> orders) async {
  print("Starting isolate with orders: $orders");
  final result = await compute(_processOrders, orders);
  print("Isolate completed with result: $result");
  return result;
}

List<String> _processOrders(List<Map<String, dynamic>> orders) {
  final Map<String, int> labelCounts = {};

  for (var order in orders) {
    final labels = order['tags'] as List<dynamic>;
    for (var label in labels) {
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;
    }
  }

  // Ordenar las labels por cantidad de compras
  final sortedLabels = labelCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Retornar el top 5 de labels
  return sortedLabels.take(5).map((entry) => entry.key).toList();
}

class RecommendationService {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  Future<List<RecommendationModel>> getRecommendedProducts() async {
    // Obtener el historial de compras del usuario
    final purchaseHistory = await _firebaseDAO.getUserPurchaseHistory();
    print("Purchase history: $purchaseHistory");

    // Generar recomendaciones basadas en las labels
    final recommendedLabels = await generateRecommendations(purchaseHistory);
    print("Recommended labels: $recommendedLabels");

    // Obtener productos populares basados en las labels recomendadas
    final popularProducts = await _firebaseDAO.getPopularProductsByTags(recommendedLabels.take(3).toList());
    print("Popular products: $popularProducts");

    return popularProducts.map((product) => RecommendationModel.fromMap(product)).toList();
  }

 Future<List<Map<String, dynamic>>> getRecommendedFinds() async {
  final firebaseDAO = FirebaseDAO();

  try {
    // Obtener el historial de compras del usuario
    final purchaseHistory = await firebaseDAO.getUserPurchaseHistory();
    print("Purchase history: $purchaseHistory");

    if (purchaseHistory.isEmpty) {
      print("No purchase history found.");
      return []; // Retornar una lista vacía si no hay historial de compras
    }

    // Tomar los labels de las 3 últimas órdenes
    final recentOrders = purchaseHistory.take(3).toList();
    final List<String> labels = [];
    for (var order in recentOrders) {
      labels.addAll(List<String>.from(order['tags'])); // Convertir a List<String>
    }

    // Eliminar duplicados
    final uniqueLabels = labels.toSet().toList();
    print("Recommended labels: $uniqueLabels");

    if (uniqueLabels.isEmpty) {
      print("No recommended labels found.");
      return []; // Retornar una lista vacía si no hay etiquetas recomendadas
    }

    // Obtener finds basados en los labels recomendados
    final recommendedFinds = await firebaseDAO.getFindsByTags(uniqueLabels);
    print("Recommended finds: $recommendedFinds");

    return recommendedFinds;
  } catch (e) {
    print("Error in RecommendationService: $e");
    return [];
  }
}}