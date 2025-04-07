// lib/data/local_chat_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/models/chat_model.dart';
import 'package:unimarket/models/message_model.dart';

class LocalChatStorage {
  // Key prefixes
  static const String _chatPrefix = 'chat_';
  static const String _messagePrefix = 'message_';
  static const String _chatListKey = 'chat_list';
  
  // Save a chat to local storage
  Future<bool> saveChat(ChatModel chat) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Prepare chat data
      final Map<String, dynamic> chatData = chat.toMap();
      chatData['id'] = chat.id;
      
      // Handle DateTime serialization
      if (chat.lastMessageTime != null) {
        chatData['lastMessage']['timestamp'] = chat.lastMessageTime!.toIso8601String();
      }
      
      // Save the chat
      final bool result = await prefs.setString(
        '$_chatPrefix${chat.id}',
        jsonEncode(chatData),
      );
      
      // Update the list of chats
      if (result) {
        await _addChatToList(chat.id);
      }
      
      return result;
    } catch (e) {
      print('Error saving chat locally: $e');
      return false;
    }
  }
  
  // Get a chat from local storage
  Future<ChatModel?> getChat(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? chatString = prefs.getString('$_chatPrefix$chatId');
      
      if (chatString == null) return null;
      
      // Parse chat data
      final Map<String, dynamic> chatData = jsonDecode(chatString);
      
      // Handle DateTime deserialization
      if (chatData['lastMessage'] != null && chatData['lastMessage']['timestamp'] != null) {
        final String timestampString = chatData['lastMessage']['timestamp'];
        chatData['lastMessage']['timestamp'] = DateTime.parse(timestampString);
      }
      
      return ChatModel.fromFirestore(chatData, chatId);
    } catch (e) {
      print('Error getting chat from local storage: $e');
      return null;
    }
  }
  
  // Save a message to local storage
  Future<bool> saveMessage(MessageModel message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Prepare message data
      final Map<String, dynamic> messageData = message.toMap();
      messageData['id'] = message.id;
      messageData['timestamp'] = message.timestamp.toIso8601String();
      
      // Save the message
      final bool result = await prefs.setString(
        '$_messagePrefix${message.chatId}_${message.id}',
        jsonEncode(messageData),
      );
      
      // Update the list of messages for this chat
      if (result) {
        await _addMessageToChat(message.chatId, message.id);
      }
      
      return result;
    } catch (e) {
      print('Error saving message locally: $e');
      return false;
    }
  }
  
  // Get messages for a chat from local storage
  Future<List<MessageModel>> getChatMessages(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? messageIds = prefs.getStringList('${_chatPrefix}${chatId}_messages');
      
      if (messageIds == null) return [];
      
      final List<MessageModel> messages = [];
      
      for (final messageId in messageIds) {
        final String? messageString = prefs.getString('$_messagePrefix${chatId}_$messageId');
        
        if (messageString != null) {
          final Map<String, dynamic> messageData = jsonDecode(messageString);
          
          // Handle DateTime deserialization
          if (messageData['timestamp'] != null) {
            messageData['timestamp'] = DateTime.parse(messageData['timestamp']);
          }
          
          messages.add(MessageModel.fromFirestore(messageData, messageId));
        }
      }
      
      // Sort by timestamp descending (newest first)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return messages;
    } catch (e) {
      print('Error getting messages from local storage: $e');
      return [];
    }
  }
  
  // Get all locally stored chats
  Future<List<ChatModel>> getAllChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? chatIds = prefs.getStringList(_chatListKey);
      
      if (chatIds == null) return [];
      
      final List<ChatModel> chats = [];
      
      for (final chatId in chatIds) {
        final ChatModel? chat = await getChat(chatId);
        if (chat != null) {
          chats.add(chat);
        }
      }
      
      // Sort by last message time
      chats.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      
      return chats;
    } catch (e) {
      print('Error getting all chats from local storage: $e');
      return [];
    }
  }
  
  // Delete a chat and all its messages
  Future<bool> deleteChat(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get message IDs for this chat
      final List<String>? messageIds = prefs.getStringList('${_chatPrefix}${chatId}_messages');
      
      // Delete all messages
      if (messageIds != null) {
        for (final messageId in messageIds) {
          await prefs.remove('$_messagePrefix${chatId}_$messageId');
        }
      }
      
      // Delete message list
      await prefs.remove('${_chatPrefix}${chatId}_messages');
      
      // Delete chat
      await prefs.remove('$_chatPrefix$chatId');
      
      // Remove from chat list
      await _removeChatFromList(chatId);
      
      return true;
    } catch (e) {
      print('Error deleting chat from local storage: $e');
      return false;
    }
  }
  
  // Helper method to add a chat ID to the list of chats
  Future<void> _addChatToList(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> chatIds = prefs.getStringList(_chatListKey) ?? [];
    
    if (!chatIds.contains(chatId)) {
      chatIds.add(chatId);
      await prefs.setStringList(_chatListKey, chatIds);
    }
  }
  
  // Helper method to remove a chat ID from the list of chats
  Future<void> _removeChatFromList(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> chatIds = prefs.getStringList(_chatListKey) ?? [];
    
    chatIds.remove(chatId);
    await prefs.setStringList(_chatListKey, chatIds);
  }
  
  // Helper method to add a message ID to the list of messages for a chat
  Future<void> _addMessageToChat(String chatId, String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> messageIds = prefs.getStringList('${_chatPrefix}${chatId}_messages') ?? [];
    
    if (!messageIds.contains(messageId)) {
      messageIds.add(messageId);
      await prefs.setStringList('${_chatPrefix}${chatId}_messages', messageIds);
    }
  }
}