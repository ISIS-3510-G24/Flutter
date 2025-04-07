// lib/models/chat_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final bool hasUnreadMessages;
  final Map<String, dynamic>? additionalData;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.hasUnreadMessages = false,
    this.additionalData,
  });

  factory ChatModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    // Safely extract participants as a list of strings
    List<String> extractParticipants() {
      try {
        if (data['participants'] is List) {
          return List<String>.from(
            (data['participants'] as List).map((item) => item.toString())
          );
        }
        return [];
      } catch (e) {
        print('Error parsing participants: $e');
        return [];
      }
    }
DateTime? extractTimestamp() {
  try {
    if (data['lastMessage'] == null || data['lastMessage']['timestamp'] == null) {
      return null;
    }
    
    final timestamp = data['lastMessage']['timestamp'];
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
        return null;
      }
    } else if (timestamp is Map) {
      // Handle server timestamp format
      if (timestamp.containsKey('seconds')) {
        final seconds = timestamp['seconds'];
        final nanoseconds = timestamp['nanoseconds'] ?? 0;
        if (seconds is int) {
          // Fix: Convert to int before division
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000).toInt() as int,
          );
        }
      }
    }
    print('Unhandled timestamp format: ${timestamp.runtimeType}');
    return null;
  } catch (e) {
    print('Error parsing timestamp: $e');
    return null;
  }
}

    // Safely extract text from lastMessage
    String? extractLastMessageText() {
      try {
        if (data['lastMessage'] == null) return null;
        if (data['lastMessage'] is Map) {
          return data['lastMessage']['text']?.toString();
        }
        return null;
      } catch (e) {
        print('Error parsing last message text: $e');
        return null;
      }
    }

    // Safely extract sender ID
    String? extractSenderId() {
      try {
        if (data['lastMessage'] == null) return null;
        if (data['lastMessage'] is Map) {
          return data['lastMessage']['senderId']?.toString();
        }
        return null;
      } catch (e) {
        print('Error parsing senderId: $e');
        return null;
      }
    }

    return ChatModel(
      id: documentId,
      participants: extractParticipants(),
      lastMessage: extractLastMessageText(),
      lastMessageTime: extractTimestamp(),
      lastMessageSenderId: extractSenderId(),
      hasUnreadMessages: data['hasUnreadMessages'] == true,
      additionalData: data,
    );
  }

  Map<String, dynamic> toMap() {
    final lastMessageMap = lastMessage != null ? {
      'text': lastMessage,
      'timestamp': lastMessageTime,
      'senderId': lastMessageSenderId,
    } : null;

    return {
      'participants': participants,
      'lastMessage': lastMessageMap,
      'hasUnreadMessages': hasUnreadMessages,
    };
  }
}