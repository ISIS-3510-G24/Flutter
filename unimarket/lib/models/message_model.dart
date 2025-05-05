import 'package:cloud_firestore/cloud_firestore.dart';

// Add this enum outside the class
enum MessageStatus {
  sending,
  sent,
  failed,
  pending
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final MessageStatus status; // New field
  final Map<String, dynamic>? additionalData;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.status = MessageStatus.sent, // Default status
    this.additionalData,
  });

  factory MessageModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    // Get status from additionalData if available
    MessageStatus messageStatus = MessageStatus.sent;
    if (data['status'] != null) {
      final statusIndex = data['status'] as int;
      messageStatus = MessageStatus.values[statusIndex < MessageStatus.values.length ? statusIndex : 1];
    }
    
    return MessageModel(
      id: documentId,
      chatId: data['chatId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      timestamp: _extractTimestamp(data),
      isRead: data['isRead'] == true,
      status: messageStatus,
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
      'status': status.index, // Add status to map
    };
  }
  
  // Create a copy of this message with different properties
  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    DateTime? timestamp,
    bool? isRead,
    MessageStatus? status,
    Map<String, dynamic>? additionalData,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}