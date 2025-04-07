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
    return MessageModel(
      id: documentId,
      chatId: data['chatId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      timestamp: _extractTimestamp(data),
      isRead: data['isRead'] == true,
      additionalData: data,
    );
  }

  static DateTime _extractTimestamp(Map<String, dynamic> data) {
    try {
      final timestamp = data['timestamp'];
      
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        try {
          return DateTime.parse(timestamp);
        } catch (e) {
          print('Error parsing timestamp string: $e');
        }
      } else if (timestamp is Map) {
        try {
          if (timestamp.containsKey('seconds')) {
            final seconds = timestamp['seconds'];
            final nanoseconds = timestamp['nanoseconds'] ?? 0;
            
            if (seconds is int && nanoseconds is int) {
              return DateTime.fromMillisecondsSinceEpoch(
                seconds * 1000 + (nanoseconds ~/ 1000000),
              );
            }
            
            // Handle case where seconds/nanoseconds might be num instead of int
            if (seconds is num && nanoseconds is num) {
              return DateTime.fromMillisecondsSinceEpoch(
                seconds.toInt() * 1000 + (nanoseconds ~/ 1000000),
              );
            }
          }
        } catch (e) {
          print('Error parsing timestamp map: $e');
        }
      }
      
      // Default to current time if parsing fails
      print('Using current time as fallback for message timestamp');
      return DateTime.now();
    } catch (e) {
      print('Error extracting timestamp in MessageModel: $e');
      return DateTime.now();
    }
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