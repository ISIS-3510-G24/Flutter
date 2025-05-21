import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unimarket/models/chat_model.dart';
import 'package:unimarket/models/message_model.dart';

class HiveChatStorage {
  // Box names
  static const String _chatBoxName = 'chats';
  static const String _messageBoxName = 'messages';
  static const String _chatListKey = 'chat_list';
  
  static bool isInitialized = false;
  static bool _isInitializing = false;
  
  // Initialize Hive with better error handling and recovery
  static Future<void> initialize() async {
    if (isInitialized) {
      print('HiveChatStorage: Already initialized');
      return;
    }
    
    if (_isInitializing) {
      print('HiveChatStorage: Initialization already in progress');
      // Wait for initialization to complete
      int attempts = 0;
      while (_isInitializing && attempts < 10) {
        await Future.delayed(Duration(milliseconds: 200));
        attempts++;
      }
      if (isInitialized) return;
    }
    
    _isInitializing = true;
    
    try {
      print('HiveChatStorage: Initializing Hive...');
      
      // Initialize Hive
      await Hive.initFlutter();
      
      // Ensure directory exists
      final appDir = await getApplicationDocumentsDirectory();
      final hivePath = '${appDir.path}/hive';
      await Directory(hivePath).create(recursive: true);
      
      // Open boxes with retries
      await _openBoxWithRetry(_chatBoxName);
      await _openBoxWithRetry(_messageBoxName);
      
      isInitialized = true;
      _isInitializing = false;
      print('HiveChatStorage: Initialized storage boxes successfully');
    } catch (e) {
      print('HiveChatStorage: Error initializing storage boxes: $e');
      isInitialized = false;
      _isInitializing = false;
      
      // Try recovery by deleting corrupted boxes
      try {
        await _recoverCorruptedBoxes();
      } catch (recoveryError) {
        print('HiveChatStorage: Recovery failed: $recoveryError');
      }
      
      rethrow;
    }
  }
  
  // Helper to open a box with retry
  static Future<Box> _openBoxWithRetry(String boxName) async {
    int attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
      try {
        if (!Hive.isBoxOpen(boxName)) {
          final box = await Hive.openBox(boxName);
          print('HiveChatStorage: Opened $boxName box');
          return box;
        } else {
          return Hive.box(boxName);
        }
      } catch (e) {
        attempts++;
        print('HiveChatStorage: Error opening $boxName box (attempt $attempts): $e');
        
        if (attempts >= maxAttempts) {
          rethrow;
        }
        
        // Delete potentially corrupted box file and retry
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final boxFile = File('${appDir.path}/hive/$boxName.hive');
          if (await boxFile.exists()) {
            await boxFile.delete();
            print('HiveChatStorage: Deleted corrupted $boxName box file');
          }
        } catch (deleteError) {
          print('HiveChatStorage: Error deleting box file: $deleteError');
        }
        
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
    
    throw Exception('Failed to open box $boxName after $maxAttempts attempts');
  }
  
  // Recovery method for corrupted boxes
  static Future<void> _recoverCorruptedBoxes() async {
    print('HiveChatStorage: Attempting recovery of corrupted boxes');
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hivePath = '${appDir.path}/hive';
      
      // Delete all .hive and .lock files
      final hiveDir = Directory(hivePath);
      if (await hiveDir.exists()) {
        await for (final entity in hiveDir.list()) {
          if (entity is File && 
              (entity.path.endsWith('.hive') || entity.path.endsWith('.lock'))) {
            await entity.delete();
            print('HiveChatStorage: Deleted ${entity.path}');
          }
        }
      }
      
      print('HiveChatStorage: Recovery completed');
    } catch (e) {
      print('HiveChatStorage: Error during recovery: $e');
      rethrow;
    }
  }
  
  // Ensure boxes are open before using them
  static Future<void> _ensureBoxesOpen() async {
    if (!isInitialized) {
      await initialize();
    }
    
    if (!Hive.isBoxOpen(_chatBoxName)) {
      await _openBoxWithRetry(_chatBoxName);
    }
    
    if (!Hive.isBoxOpen(_messageBoxName)) {
      await _openBoxWithRetry(_messageBoxName);
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
  
  // Save a chat to storage with retry and error handling
  Future<bool> saveChat(ChatModel chat) async {
    int attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
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
        attempts++;
        print('HiveChatStorage: Error saving chat ${chat.id} (attempt $attempts): $e');
        
        if (attempts >= maxAttempts) {
          return false;
        }
        
        await Future.delayed(Duration(milliseconds: 300 * attempts));
        
        // Try to recover if needed
        if (e.toString().contains('box not open') || e.toString().contains('HiveError')) {
          await _ensureBoxesOpen();
        }
      }
    }
    
    return false;
  }
  
  // Get a chat from storage with better error handling
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
            // Set a fallback timestamp
            chatData['lastMessageTime'] = DateTime.now();
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
      
      // If box not open error, try to reopen
      if (e.toString().contains('box not open') || e.toString().contains('HiveError')) {
        await _ensureBoxesOpen();
        
        // Try one more time
        try {
          final box = await _chatBox;
          final String? chatString = box.get(chatId);
          
          if (chatString != null) {
            final Map<String, dynamic> chatData = jsonDecode(chatString);
            
            if (chatData.containsKey('lastMessageTime') && chatData['lastMessageTime'] != null) {
              chatData['lastMessageTime'] = DateTime.parse(chatData['lastMessageTime']);
            }
            
            return ChatModel.fromFirestore(chatData, chatId);
          }
        } catch (retryError) {
          print('HiveChatStorage: Retry error: $retryError');
        }
      }
      
      return null;
    }
  }
  
  // Save a message to storage with retry
  Future<bool> saveMessage(MessageModel message) async {
    int attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
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
        attempts++;
        print('HiveChatStorage: Error saving message ${message.id} (attempt $attempts): $e');
        
        if (attempts >= maxAttempts) {
          return false;
        }
        
        await Future.delayed(Duration(milliseconds: 300 * attempts));
        
        // Try to recover if needed
        if (e.toString().contains('box not open') || e.toString().contains('HiveError')) {
          await _ensureBoxesOpen();
        }
      }
    }
    
    return false;
  }
  
  // Save multiple messages with batch processing
  Future<bool> saveMessages(List<MessageModel> messages) async {
    try {
      print('HiveChatStorage: Saving ${messages.length} messages');
      
      int successCount = 0;
      
      for (final message in messages) {
        final success = await saveMessage(message);
        if (success) successCount++;
      }
      
      print('HiveChatStorage: Saved $successCount/${messages.length} messages');
      return successCount > 0;
    } catch (e) {
      print('HiveChatStorage: Error saving multiple messages: $e');
      return false;
    }
  }
  
  // Get all messages for a chat with improved error handling
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
              try {
                messageData['timestamp'] = DateTime.parse(messageData['timestamp']);
              } catch (e) {
                // Set a fallback timestamp
                print('HiveChatStorage: Error parsing message timestamp: $e');
                messageData['timestamp'] = DateTime.now();
              }
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
      
      // If box not open error, try to reopen
      if (e.toString().contains('box not open') || e.toString().contains('HiveError')) {
        await _ensureBoxesOpen();
        
        // Try one more time
        try {
          return await getChatMessages(chatId);
        } catch (retryError) {
          print('HiveChatStorage: Retry error: $retryError');
        }
      }
      
      return [];
    }
  }
  
  // Get all stored chats with cleanup and error handling
  Future<List<ChatModel>> getAllChats() async {
    try {
      print('HiveChatStorage: Getting all chats');
      
      // Get all chat IDs
      final List<String> chatIds = await _getChatListIds();
      print('HiveChatStorage: Found ${chatIds.length} chat IDs');
      
      final List<ChatModel> chats = [];
      List<String> invalidChatIds = [];
      
      for (final chatId in chatIds) {
        final ChatModel? chat = await getChat(chatId);
        if (chat != null) {
          chats.add(chat);
        } else {
          // Keep track of invalid IDs to remove them
          invalidChatIds.add(chatId);
        }
      }
      
      // Clean up invalid chat IDs
      if (invalidChatIds.isNotEmpty) {
        print('HiveChatStorage: Cleaning up ${invalidChatIds.length} invalid chat IDs');
        for (final invalidId in invalidChatIds) {
          await _removeChatFromList(invalidId);
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
      
      // If box not open error, try to reopen
      if (e.toString().contains('box not open') || e.toString().contains('HiveError')) {
        await _ensureBoxesOpen();
        
        // Try one more time
        try {
          return await getAllChats();
        } catch (retryError) {
          print('HiveChatStorage: Retry error: $retryError');
        }
      }
      
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
  
  // Helper method to get chat list IDs with error handling
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
  
  // Get the total count of locally stored messages
  Future<int> getStoredMessagesCount() async {
    try {
      int total = 0;
      final chatIds = await _getChatListIds();
      
      for (final chatId in chatIds) {
        final messageIds = await _getChatMessageKeys(chatId);
        total += messageIds.length;
      }
      
      return total;
    } catch (e) {
      print('HiveChatStorage: Error counting stored messages: $e');
      return 0;
    }
  }
  
  // Compress old messages to save storage space
  Future<bool> compressOldMessages(int maxDaysToKeep) async {
    try {
      print('HiveChatStorage: Compressing old messages (keeping $maxDaysToKeep days)');
      
      final cutoffDate = DateTime.now().subtract(Duration(days: maxDaysToKeep));
      final chatIds = await _getChatListIds();
      int removedCount = 0;
      
      for (final chatId in chatIds) {
        // Get messages for this chat
        final messages = await getChatMessages(chatId);
        
        // Skip if no messages
        if (messages.isEmpty) continue;
        
        // Keep recent messages and the latest 10 messages regardless of date
        final messagesToKeep = messages.where((m) => 
          m.timestamp.isAfter(cutoffDate)).toList();
        
        // Always keep the most recent 10 messages
        if (messages.length > 10) {
          final latestMessages = messages.sublist(0, 10);
          for (final latestMessage in latestMessages) {
            if (!messagesToKeep.contains(latestMessage)) {
              messagesToKeep.add(latestMessage);
            }
          }
        }
        
        // If we're keeping all messages, skip
        if (messagesToKeep.length == messages.length) continue;
        
        // Get IDs of messages to remove
        final idsToKeep = messagesToKeep.map((m) => m.id).toSet();
        final messageIds = await _getChatMessageKeys(chatId);
        final idsToRemove = messageIds.where((id) => !idsToKeep.contains(id)).toList();
        
        // Remove old messages
        final messageBox = await _messageBox;
        for (final id in idsToRemove) {
          await messageBox.delete('${chatId}_$id');
          removedCount++;
        }
        
        // Update message list for this chat
        final box = await _messageBox;
        await box.put('${chatId}_messages', jsonEncode(messagesToKeep.map((m) => m.id).toList()));
      }
      
      print('HiveChatStorage: Removed $removedCount old messages');
      return true;
    } catch (e) {
      print('HiveChatStorage: Error compressing old messages: $e');
      return false;
    }
  }
}