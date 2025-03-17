import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String name;
  final String majorID;
  final Map<String, dynamic>? additionalData;

  ClassModel({
    required this.id,
    required this.name,
    required this.majorID,
    this.additionalData,
  });

  factory ClassModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return ClassModel(
      id: documentId,
      name: data['name'] ?? 'Unknown Class',
      majorID: data['majorID'] ?? '',
      additionalData: data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'majorID': majorID,
      ...?additionalData,
    };
  }
}