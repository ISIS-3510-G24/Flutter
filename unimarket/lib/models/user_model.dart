import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final String email;
  final String? photoURL;
  final String? bio;
  final double? ratingAverage;
  final int? reviewsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? major;

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.bio,
    this.ratingAverage,
    this.reviewsCount,
    this.createdAt,
    this.updatedAt,
    this.major
  });

  // Construir desde Firestore
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      displayName: data['displayName'] ?? 'Unknown User',
      email: data['email'] ?? '',
      photoURL: data['profilePicture'],
      bio: data['bio'] ?? '',
      ratingAverage: (data['ratingAverage'] ?? 0.0).toDouble(),
      reviewsCount: data['reviewsCount'] ?? 0,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now(),
      major: data['major'] ?? 'No Major',
    );
  }

  // Construir desde un Map (para Hive)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? 'Unknown User',
      email: map['email'] ?? '',
      photoURL: map['photoURL'],
      bio: map['bio'] ?? '',
      ratingAverage: (map['ratingAverage'] ?? 0.0).toDouble(),
      reviewsCount: map['reviewsCount'] ?? 0,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      major: map['major'] ?? 'No Major',
    );
  }

  // Convertir a Map para almacenamiento
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
    'profilePicture': photoURL,
    'bio': bio,
    'ratingAverage': ratingAverage,
    'reviewsCount': reviewsCount,
    'updatedAt': FieldValue.serverTimestamp(),
    'major': major, // Added major field
    };
  }
}