// lib/models/user_model.dart
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

  Map<String, dynamic> toMap() {
  return {
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