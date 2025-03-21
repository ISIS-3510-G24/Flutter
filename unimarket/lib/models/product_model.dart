import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String? id; // Document ID (null for new products)
  final String classId;
  final DateTime createdAt;
  final String description;
  final List<String> imageUrls;
  final List<String> labels;
  final String majorID;
  final double price;
  final String sellerID;
  final String status;
  final String title;
  final DateTime updatedAt;

  ProductModel({
    this.id,
    required this.classId,
    required this.createdAt,
    required this.description,
    required this.imageUrls,
    required this.labels,
    required this.majorID,
    required this.price,
    required this.sellerID,
    required this.status,
    required this.title,
    required this.updatedAt,
  });

  // Factory constructor to create a ProductModel from a Firestore document
  factory ProductModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ProductModel(
      id: docId ?? map['id'],
      classId: map['classId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      labels: List<String>.from(map['labels'] ?? []),
      majorID: map['majorID'] ?? '',
      price: (map['price'] is int) 
        ? (map['price'] as int).toDouble() 
        : (map['price'] ?? 0.0),
      sellerID: map['sellerID'] ?? '',
      status: map['status'] ?? 'Available',
      title: map['title'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert ProductModel to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'createdAt': createdAt,
      'description': description,
      'imageUrls': imageUrls,
      'labels': labels,
      'majorID': majorID,
      'price': price,
      'sellerID': sellerID,
      'status': status,
      'title': title,
      'updatedAt': updatedAt,
    };
  }
}