import 'package:flutter/foundation.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/recommendation_model.dart';

Future<List<String>> generateRecommendations(List<Map<String, dynamic>> orders) async {
  final result = await compute(_processOrders, orders);
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

  final sortedLabels = labelCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sortedLabels.take(5).map((entry) => entry.key).toList();
}

Future<List<String>> extractUniqueLabels(List<Map<String, dynamic>> recentOrders) async {
  return await compute(_extractLabelsFromRecentOrders, recentOrders);
}

List<String> _extractLabelsFromRecentOrders(List<Map<String, dynamic>> orders) {
  final List<String> labels = [];
  for (var order in orders) {
    final rawTags = order['tags'];
    if (rawTags is List) {
      labels.addAll(List<String>.from(rawTags));
    }
  }
  return labels.toSet().toList();
}

class RecommendationService {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  Future<List<RecommendationModel>> getRecommendedProducts() async {
    final purchaseHistory = await _firebaseDAO.getUserPurchaseHistory();
    final recommendedLabels = await generateRecommendations(purchaseHistory);
    final popularProducts = await _firebaseDAO.getPopularProductsByTags(recommendedLabels.take(3).toList());
    return popularProducts.map((product) => RecommendationModel.fromMap(product)).toList();
  }

  Future<List<Map<String, dynamic>>> getRecommendedFinds() async {
    final firebaseDAO = FirebaseDAO();

    try {
      final purchaseHistory = await firebaseDAO.getUserPurchaseHistory();

      if (purchaseHistory.isEmpty) {
        return [];
      }

      final recentOrders = purchaseHistory.take(3).toList();
      final uniqueLabels = await extractUniqueLabels(recentOrders);

      if (uniqueLabels.isEmpty) {
        return [];
      }

      final recommendedFinds = await firebaseDAO.getFindsByTags(uniqueLabels);
      return recommendedFinds;
    } catch (e) {
      return [];
    }
  }
}
