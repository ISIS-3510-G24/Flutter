// lib/services/unanswered_messages_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/models/message_model.dart';
import 'package:unimarket/models/chat_model.dart';
import 'package:unimarket/services/chat_service.dart';

class UnansweredMessagesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get all chats where the current user is the seller and hasn't responded
  Future<List<Map<String, dynamic>>> getUnansweredMessagesBySeller() async {
    if (currentUserId == null) {
      return [];
    }

    try {
      // 1. Get all chats where current user is a participant
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      List<Map<String, dynamic>> unansweredChats = [];

      // 2. For each chat, analyze the message history
      for (final chatDoc in chatsSnapshot.docs) {
        final chatId = chatDoc.id;
        final chatData = chatDoc.data();
        
        // Skip if there's no last message
        if (!chatData.containsKey('lastMessageSenderId') || 
            chatData['lastMessageSenderId'] == null) {
          continue;
        }
        
        // Extract key information
        final String lastMessageSenderId = chatData['lastMessageSenderId'];
        final List<String> participants = List<String>.from(
          (chatData['participants'] as List).map((item) => item.toString())
        );
        
        // Skip if the last message was sent by the current user (seller)
        if (lastMessageSenderId == currentUserId) {
          continue;
        }
        
        // Get the other participant (buyer)
        final String buyerId = participants.firstWhere(
          (id) => id != currentUserId, 
          orElse: () => ''
        );
        if (buyerId.isEmpty) continue;
        
        // Get user details
        final buyer = await _chatService.getChatParticipant(chatId);
        if (buyer == null) continue;
        
        // Get the timestamp of the last message
        final DateTime? lastMessageTime = ChatModel.fromFirestore(chatData, chatId).lastMessageTime;
        if (lastMessageTime == null) continue;
        
        // Calculate days since last message
        final int daysSinceLastMessage = DateTime.now().difference(lastMessageTime).inDays;
        
        // Get messages to check if there was a response
        final messages = await _loadLastMessages(chatId);
        final bool hasSellerResponse = _checkForSellerResponse(messages, buyerId);
        
        // If seller hasn't responded and it's been at least 1 day
        if (!hasSellerResponse && daysSinceLastMessage >= 1) {
          unansweredChats.add({
            'chatId': chatId,
            'buyer': buyer,
            'lastMessage': chatData['lastMessage'] ?? 'No message content',
            'lastMessageTime': lastMessageTime,
            'daysSinceLastMessage': daysSinceLastMessage,
          });
        }
      }
      
      // Sort by days (most days first)
      unansweredChats.sort((a, b) => 
        (b['daysSinceLastMessage'] as int).compareTo(a['daysSinceLastMessage'] as int)
      );
      
      return unansweredChats;
    } catch (e) {
      print('Error getting unanswered messages: $e');
      return [];
    }
  }
  
  // Load the last few messages from a chat
  Future<List<MessageModel>> _loadLastMessages(String chatId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(10)  // Check the last 10 messages
          .get();
      
      return messagesSnapshot.docs.map((doc) {
        final data = doc.data();
        return MessageModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      print('Error loading messages: $e');
      return [];
    }
  }
  
  // Check if the seller has responded after the buyer's message
  bool _checkForSellerResponse(List<MessageModel> messages, String buyerId) {
    if (messages.isEmpty) return false;
    
    // Get the index of the last buyer message
    int? lastBuyerMessageIndex;
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].senderId == buyerId) {
        lastBuyerMessageIndex = i;
        break;  // We start from most recent, so first buyer message is the latest
      }
    }
    
    // If no buyer message found, return true (no need for response)
    if (lastBuyerMessageIndex == null) return true;
    
    // Check if there's a seller message after the buyer's last message
    // Messages are sorted by timestamp (descending), so we check messages with index < lastBuyerMessageIndex
    for (int i = 0; i < lastBuyerMessageIndex; i++) {
      if (messages[i].senderId == currentUserId) {
        return true; // Seller has responded
      }
    }
    
    return false; // No seller response after the last buyer message
  }
  
  // Method to get all buyers waiting for 5+ days
  Future<List<Map<String, dynamic>>> getLongWaitingBuyers({int minDays = 5}) async {
    final unansweredChats = await getUnansweredMessagesBySeller();
    return unansweredChats.where((chat) => 
      (chat['daysSinceLastMessage'] as int) >= minDays
    ).toList();
  }
}