import 'package:cloud_firestore/cloud_firestore.dart';

class FindModel {
  final String id;
  String title;
  String description;
  final String image;
  final List<String> labels;
  final String major;
  final int offerCount;
  final String status;
  final DateTime timestamp;
  final int upvoteCount;
  final String userId;
  final String userName;

  FindModel({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.labels,
    required this.major,
    required this.offerCount,
    required this.status,
    required this.timestamp,
    required this.upvoteCount,
    required this.userId,
    required this.userName,
  });

  factory FindModel.fromFirestore(Map<String, dynamic> data, String id) {
    return FindModel(
      id: id,
      title: data['title'],
      description: data['description'],
      image: data['image'],
      labels: List<String>.from(data['labels']),
      major: data['major'],
      offerCount: data['offerCount'],
      status: data['status'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      upvoteCount: data['upvoteCount'],
      userId: data['userId'],
      userName: data['userName'],
    );
  }

  factory FindModel.fromMap(Map<String, dynamic> map) {
  return FindModel(
    id: map['findId'] ?? '',
    title: map['title'] ?? '',
    description: map['description'] ?? '',
    labels: List<String>.from(map['labels'] ?? []),
    image: map['image'] ?? '',
    major: map['major'] ?? '',
    offerCount: map['offerCount'] ?? 0,
    status: map['status'] ?? '',
    timestamp: map['timestamp'] is Timestamp
        ? (map['timestamp'] as Timestamp).toDate() // Convierte Timestamp a DateTime
        : map['timestamp'] as DateTime, // Usa directamente si ya es DateTime
    upvoteCount: map['upvoteCount'] ?? 0,
    userId: map['userId'] ?? '',
    userName: map['userName'] ?? '',
  );
}


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image': image,
      'labels': labels,
      'major': major,
      'offerCount': offerCount,
      'status': status,
      'timestamp': timestamp,
      'upvoteCount': upvoteCount,
      'userId': userId,
      'userName': userName,
    };
  }
}