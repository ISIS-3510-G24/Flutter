// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? additionalData;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.additionalData,
  });

  factory MessageModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    // Safely extract timestamp
    DateTime extractTimestamp() {
      try {
        final timestamp = data['timestamp'];
        if (timestamp is Timestamp) {
          return timestamp.toDate();
        } else if (timestamp is DateTime) {
          return timestamp;
        } else if (timestamp is int) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timestamp is String) {
          final parsed = DateTime.tryParse(timestamp);
          if (parsed != null) return parsed;
        }
        return DateTime.now(); // Fallback
      } catch (e) {
        print('Error parsing message timestamp: $e');
        return DateTime.now(); // Fallback
      }
    }

    return MessageModel(
      id: documentId,
      chatId: data['chatId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      timestamp: extractTimestamp(),
      isRead: data['isRead'] == true,
      additionalData: data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }
}