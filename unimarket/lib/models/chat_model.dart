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
    return ChatModel(
      id: documentId,
      participants: _extractParticipants(data),
      lastMessage: _extractLastMessageText(data),
      lastMessageTime: _extractTimestamp(data),
      lastMessageSenderId: _extractSenderId(data),
      hasUnreadMessages: data['hasUnreadMessages'] == true,
      additionalData: data,
    );
  }

  static List<String> _extractParticipants(Map<String, dynamic> data) {
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

  static DateTime? _extractTimestamp(Map<String, dynamic> data) {
    try {
      // Check if lastMessageTime is directly in data
      dynamic timestamp;
      if (data.containsKey('lastMessageTime')) {
        timestamp = data['lastMessageTime'];
      } else if (data.containsKey('lastMessage')) {
        // Nested in lastMessage
        var lastMessageData = data['lastMessage'];
        
        // Handle string format
        if (lastMessageData is String) {
          return null; // Just text, no timestamp
        }
        
        // Handle map format
        if (lastMessageData is Map) {
          timestamp = lastMessageData['timestamp'];
        }
      }
      
      if (timestamp == null) return null;
      
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is Map) {
        // Handle Firebase server timestamp format
        if (timestamp.containsKey('seconds')) {
          final seconds = timestamp['seconds'];
          final nanoseconds = timestamp['nanoseconds'] ?? 0;
          
          if (seconds is int && nanoseconds is int) {
            return DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + (nanoseconds ~/ 1000000),
            );
          }
          
          // Handle the case where seconds/nanoseconds might be num instead of int
          if (seconds is num && nanoseconds is num) {
            return DateTime.fromMillisecondsSinceEpoch(
              seconds.toInt() * 1000 + (nanoseconds ~/ 1000000),
            );
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error extracting timestamp in ChatModel: $e');
      return null;
    }
  }

  static String? _extractLastMessageText(Map<String, dynamic> data) {
    try {
      if (data['lastMessage'] == null) return null;
      
      // If lastMessage is directly a string
      if (data['lastMessage'] is String) {
        return data['lastMessage'];
      }
      
      // If lastMessage is a map with a text field
      if (data['lastMessage'] is Map) {
        return data['lastMessage']['text']?.toString();
      }
      
      return null;
    } catch (e) {
      print('Error parsing last message text: $e');
      return null;
    }
  }

  static String? _extractSenderId(Map<String, dynamic> data) {
    try {
      // Check if it's at the root level
      if (data['lastMessageSenderId'] != null) {
        return data['lastMessageSenderId'].toString();
      }
      
      // Check if it's nested in lastMessage
      if (data['lastMessage'] is Map) {
        return data['lastMessage']['senderId']?.toString();
      }
      
      return null;
    } catch (e) {
      print('Error parsing senderId: $e');
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastMessageSenderId': lastMessageSenderId,
      'hasUnreadMessages': hasUnreadMessages,
    };
  }
}