import 'package:cloud_firestore/cloud_firestore.dart';

class FindModel {
  final String id;
  final String description;
  final String title;
  final String image;
  final List<String> labels;
  final int offerCount;
  final String status;
  final DateTime timestamp;
  final int upvoteCount;
  final String userId;
  final String userName;
  final String major; // Added major field

  FindModel({
    required this.id,
    required this.description,
    required this.title,
    required this.image,
    required this.labels,
    required this.offerCount,
    required this.status,
    required this.timestamp,
    required this.upvoteCount,
    required this.userId,
    required this.userName,
    required this.major, // Initialize major field
  });

  factory FindModel.fromFirestore(Map<String, dynamic> data, String id) {
    return FindModel(
      id: id,
      description: data['description'] ?? '',
      title: data['title'] ?? '',
      image: data['image'] ?? '',
      labels: List<String>.from(data['labels'] ?? []),
      offerCount: data['offerCount'] ?? 0,
      status: data['status'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      upvoteCount: data['upvoteCount'] ?? 0,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      major: data['major'] ?? '', // Parse major field
    );
  }
}