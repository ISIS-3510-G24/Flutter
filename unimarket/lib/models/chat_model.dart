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
    // Enhanced debugging
    print('Creating ChatModel from Firestore data for $documentId:');
    print('  - participants: ${data['participants']}');
    print('  - lastMessage: ${data['lastMessage']}');
    print('  - lastMessageTime: ${data['lastMessageTime']}');
    print('  - lastMessageSenderId: ${data['lastMessageSenderId']}');
    print('  - hasUnreadMessages: ${data['hasUnreadMessages']}');
    
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
      print('Extracting timestamp from: $data');
      
      // Check if lastMessageTime is directly in data
      dynamic timestamp;
      if (data.containsKey('lastMessageTime')) {
        timestamp = data['lastMessageTime'];
        print('Found lastMessageTime: $timestamp');
      } else if (data.containsKey('lastMessage')) {
        // Nested in lastMessage
        var lastMessageData = data['lastMessage'];
        
        // Handle string format
        if (lastMessageData is String) {
          print('lastMessage is a string, no timestamp available');
          return null; // Just text, no timestamp
        }
        
        // Handle map format
        if (lastMessageData is Map) {
          timestamp = lastMessageData['timestamp'];
          print('Found timestamp in lastMessage map: $timestamp');
        }
      }
      
      if (timestamp == null) {
        print('No timestamp found in data');
        return null;
      }
      
      // Now convert the timestamp to DateTime based on its type
      if (timestamp is Timestamp) {
        print('Converting Timestamp to DateTime: ${timestamp.toDate()}');
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        print('Timestamp is already DateTime: $timestamp');
        return timestamp;
      } else if (timestamp is int) {
        print('Converting int timestamp to DateTime: ${DateTime.fromMillisecondsSinceEpoch(timestamp)}');
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        print('Parsing string timestamp: $timestamp');
        return DateTime.parse(timestamp);
      } else if (timestamp is Map) {
        // Handle Firebase server timestamp format
        if (timestamp.containsKey('seconds')) {
          final seconds = timestamp['seconds'];
          final nanoseconds = timestamp['nanoseconds'] ?? 0;
          
          print('Timestamp is Firebase format - seconds: $seconds, nanoseconds: $nanoseconds');
          
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
      
      print('Failed to convert timestamp to DateTime');
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
      print('Extracting senderId from data: $data');
      
      // Check if directly in document
      if (data.containsKey('lastMessageSenderId') && data['lastMessageSenderId'] != null) {
        print('Found lastMessageSenderId directly: ${data['lastMessageSenderId']}');
        return data['lastMessageSenderId'].toString();
      }
      
      // Check nested format
      if (data.containsKey('lastMessage') && data['lastMessage'] is Map) {
        final lastMessage = data['lastMessage'] as Map<String, dynamic>;
        if (lastMessage.containsKey('senderId')) {
          print('Found senderId in lastMessage: ${lastMessage['senderId']}');
          return lastMessage['senderId']?.toString();
        }
      }
      
      // Check at root level (some systems store it this way)
      if (data.containsKey('senderId')) {
        print('Found senderId at root level: ${data['senderId']}');
        return data['senderId'].toString();
      }
      
      print('No senderId found in data');
      return null;
    } catch (e) {
      print('Error extracting senderId: $e');
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