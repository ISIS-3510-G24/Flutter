import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String description;
  final String image;
  final double price;
  final String status;
  final DateTime timestamp;
  final String userId;
  final String userName;

  OfferModel({
    required this.id,
    required this.description,
    required this.image,
    required this.price,
    required this.status,
    required this.timestamp,
    required this.userId,
    required this.userName,
  });

  factory OfferModel.fromFirestore(Map<String, dynamic> data, String id) {
    return OfferModel(
      id: id,
      description: data['description'],
      image: data['image'],
      price: data['price'],
      status: data['status'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      userId: data['userId'],
      userName: data['userName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'image': image,
      'price': price,
      'status': status,
      'timestamp': timestamp,
      'userId': userId,
      'userName': userName,
    };
  }
}