import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:unimarket/models/chat_model.dart';
import 'package:unimarket/models/message_model.dart';

class HiveChatStorage {
  // Box names
  static const String _chatBoxName = 'chats';
  static const String _messageBoxName = 'messages';
  static const String _chatListKey = 'chat_list';
  
  static bool isInitialized = false;
  
  // Initialize Hive
  static Future<void> initialize() async {
    if (isInitialized) {
      print('HiveChatStorage: Already initialized');
      return;
    }
    
    try {
      print('HiveChatStorage: Initializing Hive...');
      await Hive.initFlutter();
      
      // Asegurarnos de que las cajas se abran correctamente
      if (!Hive.isBoxOpen(_chatBoxName)) {
        await Hive.openBox(_chatBoxName);
        print('HiveChatStorage: Opened $_chatBoxName box');
      }
      
      if (!Hive.isBoxOpen(_messageBoxName)) {
        await Hive.openBox(_messageBoxName);
        print('HiveChatStorage: Opened $_messageBoxName box');
      }
      
      isInitialized = true;
      print('HiveChatStorage: Initialized storage boxes successfully');
    } catch (e) {
      print('HiveChatStorage: Error initializing storage boxes: $e');
      isInitialized = false;
      // Intentar recuperar de error
      rethrow;
    }
  }
  
  // Ensure boxes are open before using them
  static Future<void> _ensureBoxesOpen() async {
    if (!isInitialized) {
      await initialize();
    }
    
    if (!Hive.isBoxOpen(_chatBoxName)) {
      await Hive.openBox(_chatBoxName);
    }
    
    if (!Hive.isBoxOpen(_messageBoxName)) {
      await Hive.openBox(_messageBoxName);
    }
  }
  
  // Get chat box
  Future<Box> get _chatBox async {
    await _ensureBoxesOpen();
    return Hive.box(_chatBoxName);
  }
  
  // Get message box
  Future<Box> get _messageBox async {
    await _ensureBoxesOpen();
    return Hive.box(_messageBoxName);
  }
  
  // Clear all stored data
  Future<void> clearAll() async {
    try {
      print('HiveChatStorage: Clearing all stored data');
      final chatBox = await _chatBox;
      final messageBox = await _messageBox;
      
      await chatBox.clear();
      await messageBox.clear();
      print('HiveChatStorage: All stored data cleared');
    } catch (e) {
      print('HiveChatStorage: Error clearing data: $e');
    }
  }
  
  // Save a chat to storage
  Future<bool> saveChat(ChatModel chat) async {
    try {
      print('HiveChatStorage: Saving chat ${chat.id}');
      
      // Prepare chat data for serialization
      final Map<String, dynamic> chatData = chat.toMap();
      chatData['id'] = chat.id;
      
      // Handle DateTime serialization
      if (chat.lastMessageTime != null) {
        chatData['lastMessageTime'] = chat.lastMessageTime!.toIso8601String();
      }
      
      // Save chat data
      final box = await _chatBox;
      await box.put(chat.id, jsonEncode(chatData));
      
      // Update chat list
      await _addChatToList(chat.id);
      
      print('HiveChatStorage: Chat saved: ${chat.id}');
      return true;
    } catch (e) {
      print('HiveChatStorage: Error saving chat ${chat.id}: $e');
      return false;
    }
  }
  
  // Get a chat from storage
  Future<ChatModel?> getChat(String chatId) async {
    try {
      print('HiveChatStorage: Getting chat $chatId');
      final box = await _chatBox;
      final String? chatString = box.get(chatId);
      
      if (chatString == null) {
        print('HiveChatStorage: Chat $chatId not found');
        return null;
      }
      
      // Parse chat data
      try {
        final Map<String, dynamic> chatData = jsonDecode(chatString);
        
        // Handle DateTime deserialization
        if (chatData.containsKey('lastMessageTime') && chatData['lastMessageTime'] != null) {
          try {
            chatData['lastMessageTime'] = DateTime.parse(chatData['lastMessageTime']);
          } catch (e) {
            print('HiveChatStorage: Error parsing timestamp: $e');
          }
        }
        
        print('HiveChatStorage: Retrieved chat $chatId');
        return ChatModel.fromFirestore(chatData, chatId);
      } catch (e) {
        print('HiveChatStorage: Error decoding chat data: $e');
        return null;
      }
    } catch (e) {
      print('HiveChatStorage: Error getting chat $chatId: $e');
      return null;
    }
  }
  
  // Save a message to storage
  Future<bool> saveMessage(MessageModel message) async {
    try {
      print('HiveChatStorage: Saving message ${message.id} for chat ${message.chatId}');
      
      // Create a unique key for this message
      final messageKey = '${message.chatId}_${message.id}';
      
      // Prepare message data
      final Map<String, dynamic> messageData = message.toMap();
      messageData['id'] = message.id;
      
      // Handle DateTime serialization
      messageData['timestamp'] = message.timestamp.toIso8601String();
      
      // Save message
      final box = await _messageBox;
      await box.put(messageKey, jsonEncode(messageData));
      
      // Update message list for this chat
      await _addMessageToChat(message.chatId, message.id);
      
      print('HiveChatStorage: Message saved: $messageKey');
      return true;
    } catch (e) {
      print('HiveChatStorage: Error saving message ${message.id}: $e');
      return false;
    }
  }
  
  // Save multiple messages
  Future<bool> saveMessages(List<MessageModel> messages) async {
    try {
      print('HiveChatStorage: Saving ${messages.length} messages');
      
      for (final message in messages) {
        await saveMessage(message);
      }
      
      return true;
    } catch (e) {
      print('HiveChatStorage: Error saving multiple messages: $e');
      return false;
    }
  }
  
  // Get all messages for a chat
  Future<List<MessageModel>> getChatMessages(String chatId) async {
    try {
      print('HiveChatStorage: Getting messages for chat $chatId');
      
      // Get message IDs for this chat
      final List<String> messageKeys = await _getChatMessageKeys(chatId);
      print('HiveChatStorage: Found ${messageKeys.length} message keys');
      
      final List<MessageModel> messages = [];
      final box = await _messageBox;
      
      for (final messageId in messageKeys) {
        final messageKey = '${chatId}_$messageId';
        final String? messageString = box.get(messageKey);
        
        if (messageString != null) {
          try {
            final Map<String, dynamic> messageData = jsonDecode(messageString);
            
            // Handle DateTime deserialization
            if (messageData.containsKey('timestamp') && messageData['timestamp'] != null) {
              messageData['timestamp'] = DateTime.parse(messageData['timestamp']);
            }
            
            messages.add(MessageModel.fromFirestore(messageData, messageId));
          } catch (e) {
            print('HiveChatStorage: Error parsing message $messageId: $e');
          }
        }
      }
      
      // Sort by timestamp (newest first)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      print('HiveChatStorage: Retrieved ${messages.length} messages for chat $chatId');
      return messages;
    } catch (e) {
      print('HiveChatStorage: Error getting messages for chat $chatId: $e');
      return [];
    }
  }
  
  // Get all stored chats
  Future<List<ChatModel>> getAllChats() async {
    try {
      print('HiveChatStorage: Getting all chats');
      
      // Get all chat IDs
      final List<String> chatIds = await _getChatListIds();
      print('HiveChatStorage: Found ${chatIds.length} chat IDs');
      
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
      
      print('HiveChatStorage: Retrieved ${chats.length} chats');
      return chats;
    } catch (e) {
      print('HiveChatStorage: Error getting all chats: $e');
      return [];
    }
  }
  
  // Delete a chat and all its messages
  Future<bool> deleteChat(String chatId) async {
    try {
      print('HiveChatStorage: Deleting chat $chatId');
      
      // Get message IDs for this chat
      final List<String> messageIds = await _getChatMessageKeys(chatId);
      final messageBox = await _messageBox;
      final chatBox = await _chatBox;
      
      // Delete all messages
      for (final messageId in messageIds) {
        final messageKey = '${chatId}_$messageId';
        await messageBox.delete(messageKey);
      }
      
      // Delete chat metadata
      await messageBox.delete('${chatId}_messages');
      await chatBox.delete(chatId);
      
      // Remove from chat list
      await _removeChatFromList(chatId);
      
      print('HiveChatStorage: Chat $chatId deleted');
      return true;
    } catch (e) {
      print('HiveChatStorage: Error deleting chat $chatId: $e');
      return false;
    }
  }
  
  // Update a chat's unread status
  Future<bool> updateChatUnreadStatus(String chatId, bool hasUnreadMessages) async {
    try {
      print('HiveChatStorage: Updating unread status for chat $chatId to $hasUnreadMessages');
      
      final ChatModel? chat = await getChat(chatId);
      if (chat == null) {
        print('HiveChatStorage: Chat $chatId not found for status update');
        return false;
      }
      
      // Create updated chat with new status
      final updatedChat = ChatModel(
        id: chat.id,
        participants: chat.participants,
        lastMessage: chat.lastMessage,
        lastMessageTime: chat.lastMessageTime,
        lastMessageSenderId: chat.lastMessageSenderId,
        hasUnreadMessages: hasUnreadMessages,
        additionalData: chat.additionalData,
      );
      
      // Save updated chat
      return await saveChat(updatedChat);
    } catch (e) {
      print('HiveChatStorage: Error updating unread status for chat $chatId: $e');
      return false;
    }
  }
  
  // Helper method to get chat list IDs
  Future<List<String>> _getChatListIds() async {
    try {
      final box = await _chatBox;
      final String? listJson = box.get(_chatListKey);
      if (listJson == null) return [];
      
      final List<dynamic> list = jsonDecode(listJson);
      return list.map((id) => id.toString()).toList();
    } catch (e) {
      print('HiveChatStorage: Error getting chat list IDs: $e');
      return [];
    }
  }
  
  // Helper method to get message keys for a chat
  Future<List<String>> _getChatMessageKeys(String chatId) async {
    try {
      final box = await _messageBox;
      final String? listJson = box.get('${chatId}_messages');
      if (listJson == null) return [];
      
      final List<dynamic> list = jsonDecode(listJson);
      return list.map((id) => id.toString()).toList();
    } catch (e) {
      print('HiveChatStorage: Error getting message keys for chat $chatId: $e');
      return [];
    }
  }
  
  // Helper method to add a chat ID to the list of chats
  Future<void> _addChatToList(String chatId) async {
    try {
      List<String> chatIds = await _getChatListIds();
      
      if (!chatIds.contains(chatId)) {
        chatIds.add(chatId);
        final box = await _chatBox;
        await box.put(_chatListKey, jsonEncode(chatIds));
        print('HiveChatStorage: Added chat $chatId to list');
      }
    } catch (e) {
      print('HiveChatStorage: Error adding chat $chatId to list: $e');
    }
  }
  
  // Helper method to remove a chat ID from the list of chats
  Future<void> _removeChatFromList(String chatId) async {
    try {
      List<String> chatIds = await _getChatListIds();
      
      if (chatIds.contains(chatId)) {
        chatIds.remove(chatId);
        final box = await _chatBox;
        await box.put(_chatListKey, jsonEncode(chatIds));
        print('HiveChatStorage: Removed chat $chatId from list');
      }
    } catch (e) {
      print('HiveChatStorage: Error removing chat $chatId from list: $e');
    }
  }
  
  // Helper method to add a message ID to a chat's message list
  Future<void> _addMessageToChat(String chatId, String messageId) async {
    try {
      List<String> messageIds = await _getChatMessageKeys(chatId);
      
      if (!messageIds.contains(messageId)) {
        messageIds.add(messageId);
        final box = await _messageBox;
        await box.put('${chatId}_messages', jsonEncode(messageIds));
      }
    } catch (e) {
      print('HiveChatStorage: Error adding message $messageId to chat $chatId: $e');
    }
  }
}