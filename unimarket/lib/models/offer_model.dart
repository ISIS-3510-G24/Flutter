import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String description;
  final String image;
  final double price;
  final String status;
  final DateTime timestamp;
  final String userId;
  final String username;

  OfferModel({
    required this.id,
    required this.description,
    required this.image,
    required this.price,
    required this.status,
    required this.timestamp,
    required this.userId,
    required this.username,
  });

  factory OfferModel.fromFirestore(Map<String, dynamic> data, String id) {
    return OfferModel(
      id: id,
      description: data['description'] ?? '',
      image: data['image'] ?? '',
      price: data['price'] ?? 0.0,
      status: data['status'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
    );
  }
}