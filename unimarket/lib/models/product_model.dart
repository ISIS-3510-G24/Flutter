import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String? id; // Document ID (null for new products)
  final String classId;
  final DateTime createdAt;
  final List<String>? pendingImagePaths; // New field for local paths
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
    this.pendingImagePaths, // Optional field for offline mode
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

  // Fábrica para cache/local storage
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      classId: json['classId'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      description: json['description'] ?? '',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      labels: List<String>.from(json['labels'] ?? []),
      majorID: json['majorID'] ?? '',
      price: (json['price'] is int) 
          ? (json['price'] as int).toDouble() 
          : (json['price'] ?? 0.0),
      sellerID: json['sellerID'] ?? '',
      status: json['status'] ?? 'Available',
      title: json['title'] ?? '',
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),

      pendingImagePaths: (json['pendingImagePaths'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

// Create a copy with some fields replaced
  ProductModel copyWith({
    String? id,
    String? title,
    double? price,
    String? description,
    List<String>? imageUrls,
    List<String>? pendingImagePaths,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sellerId,
    String? category,
    String? condition,
    bool? isAvailable,
  }) {
    return ProductModel(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      pendingImagePaths: pendingImagePaths ?? this.pendingImagePaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sellerID: sellerId ?? sellerID,
      classId: category ?? classId,
      status: condition ?? status,
      labels: isAvailable != null && isAvailable ? ['Available'] : labels, majorID: '',
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

  // Convert ProductModel to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classId': classId,
      'createdAt': createdAt.toIso8601String(),
      'description': description,
      'imageUrls': imageUrls,
      'labels': labels,
      'majorID': majorID,
      'price': price,
      'sellerID': sellerID,
      'status': status,
      'pendingImagePaths': pendingImagePaths,
      'title': title,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}