import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/models/chat_model.dart';
import 'package:unimarket/models/message_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/services/auth_storage_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/data/hive_chat_storage.dart';

class ChatService {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Services
  final UserService _userService = UserService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final HiveChatStorage _localStorage = HiveChatStorage();
  
  // Cached data
  Map<String, UserModel?> _userCache = {};
  Map<String, StreamController<List<MessageModel>>> _messageControllers = {};
  
  // Singleton pattern
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();
  
  // Initialize service
  Future<void> initialize() async {
    try {
      print('ChatService: Initializing...');
      await HiveChatStorage.initialize();
      
      // Clean up controllers
      _disposeAllControllers();
      
      print('ChatService: Initialization complete');
    } catch (e) {
      print('ChatService: Error during initialization: $e');
    }
  }
  
  // Clean up when app is closed
  void dispose() {
    _disposeAllControllers();
  }
  
  // Dispose all active stream controllers
  void _disposeAllControllers() {
    for (final controller in _messageControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _messageControllers.clear();
  }
  
  // Get current user ID
  //DEPRECATED BC IT DOESNT FOLLOW OFFLINE SCENARIO HANDLING
  //String? get currentUserId => _auth.currentUser?.uid;
  
  //Aux method that gets the currentuserId in both online and offline scenarios
  Future<String?> getCurrentUserId() async {
    // First try Firebase auth
    final firebaseUserId = _auth.currentUser?.uid;
    if (firebaseUserId != null) return firebaseUserId;
    
    // Fallback to biometric storage
    try {
      final biometricUserId = await BiometricAuthService.getSavedUserID();
      if (biometricUserId != null) {
        return biometricUserId;
      }
    } catch (e) {
      print('Failed to get user ID from biometric storage: $e');
    }
    
    return null;
  }

  // Get user chats with improved offline support
  Stream<List<ChatModel>> getUserChats() {
    final controller = StreamController<List<ChatModel>>();
    
    // Function to load local chats
    Future<void> loadLocalChats() async {
      try {
        print('ChatService: Loading local chats');
        final localChats = await _localStorage.getAllChats();
        if (!controller.isClosed) {
          controller.add(localChats);
          print('ChatService: Loaded ${localChats.length} local chats');
        }
      } catch (e) {
        print('ChatService: Error loading local chats: $e');
        if (!controller.isClosed) {
          controller.add([]);
        }
      }
    }
    
    // Function to set up Firestore listener
    StreamSubscription? firestoreSubscription;
    Future<void> setupFirestoreListener() async {
      // Ensure current user exists
      final userId = await getCurrentUserId();
      if (userId == null) {
        print('ChatService: No current user');
        controller.add([]);
        return;
      }
      
      // Check connectivity
      final isOnline = await _connectivityService.checkConnectivity();
      if (!isOnline) {
        print('ChatService: Device is offline, using local chats only');
        await loadLocalChats();
        return;
      }
      
      try {
        print('ChatService: Setting up Firestore chats listener');
        
        // Listen to chats where current user is a participant
        firestoreSubscription = _firestore
            .collection('chats')
            .where('participants', arrayContains: userId)
            .snapshots()
            .listen(
          (snapshot) async {
            try {
              print('ChatService: Received ${snapshot.docs.length} chats from Firestore');
              
              final List<ChatModel> chats = [];
              
              for (final doc in snapshot.docs) {
                try {
                  final data = doc.data();
                  final chat = ChatModel.fromFirestore(data, doc.id);
                  
                  // Save to local storage
                  await _localStorage.saveChat(chat);
                  
                  chats.add(chat);
                } catch (e) {
                  print('ChatService: Error processing chat document ${doc.id}: $e');
                }
              }
              
              // Sort by last message time
              chats.sort((a, b) {
                if (a.lastMessageTime == null) return 1;
                if (b.lastMessageTime == null) return -1;
                return b.lastMessageTime!.compareTo(a.lastMessageTime!);
              });
              
              if (!controller.isClosed) {
                controller.add(chats);
                
                // Preload user data in background
                _preloadChatUsers(chats);
              }
              
            } catch (e) {
              print('ChatService: Error processing chats snapshot: $e');
              // If there's an error, fall back to local storage
              await loadLocalChats();
            }
          },
          onError: (error) {
            print('ChatService: Error listening to Firestore chats: $error');
            // On error, fall back to local storage
            loadLocalChats();
          },
        );
      } catch (e) {
        print('ChatService: Error setting up Firestore listener: $e');
        // Fall back to local storage
        await loadLocalChats();
      }
    }
    
    // Initial setup
    setupFirestoreListener();
    
    // Handle controller disposal
    controller.onCancel = () {
      print('ChatService: Chat stream cancelled');
      firestoreSubscription?.cancel();
    };
    
    return controller.stream;
  }
  
  
// Preload chat participants for better performance
Future<void> _preloadChatUsers(List<ChatModel> chats) async {
  try {
    final Set<String> userIds = {};
    
    // Get all unique participant IDs except current user
    for (final chat in chats) {
      for (final participantId in chat.participants) {
        final userId = await getCurrentUserId();
        if (participantId != userId && !_userCache.containsKey(participantId)) {
          userIds.add(participantId);
        }
      }
    }
    
    // Skip if no users to preload
    if (userIds.isEmpty) return;
    
    print('ChatService: Preloading data for ${userIds.length} users');
    
    // Cargar cada usuario en la lista
    for (final userId in userIds) {
      _userService.getUserById(userId).then((user) {
        if (user != null) {
          _userCache[userId] = user;
          print('ChatService: Preloaded user data for user $userId');
        }
      });
    }
  } catch (e) {
    print('ChatService: Error preloading chat users: $e');
  }
}
  // Get chat messages with improved offline support
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    // Reuse controller if it exists
    if (_messageControllers.containsKey(chatId) && 
        !_messageControllers[chatId]!.isClosed) {
      print('ChatService: Reusing existing messages controller for chat $chatId');
      return _messageControllers[chatId]!.stream;
    }
    
    print('ChatService: Creating new messages controller for chat $chatId');
    final controller = StreamController<List<MessageModel>>();
    _messageControllers[chatId] = controller;
    
    // Function to load local messages
    Future<void> loadLocalMessages() async {
      try {
        print('ChatService: Loading local messages for chat $chatId');
        final localMessages = await _localStorage.getChatMessages(chatId);
        if (!controller.isClosed) {
          controller.add(localMessages);
          print('ChatService: Loaded ${localMessages.length} local messages');
        }
      } catch (e) {
        print('ChatService: Error loading local messages: $e');
        if (!controller.isClosed) {
          controller.add([]);
        }
      }
    }
    
    // Function to set up Firestore listener
    StreamSubscription? firestoreSubscription;
    Future<void> setupFirestoreListener() async {
      // Check connectivity first
      final isOnline = await _connectivityService.checkConnectivity();
      if (!isOnline) {
        print('ChatService: Device is offline, using local messages only');
        await loadLocalMessages();
        return;
      }
      
      try {
        print('ChatService: Setting up Firestore messages listener for chat $chatId');
        
        firestoreSubscription = _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(100) // Limit to most recent messages
            .snapshots()
            .listen(
          (snapshot) async {
            try {
              print('ChatService: Received ${snapshot.docs.length} messages from Firestore');
              
              final List<MessageModel> messages = [];
              
              for (final doc in snapshot.docs) {
                try {
                  final data = doc.data();
                  final message = MessageModel.fromFirestore(data, doc.id);
                  
                  // Save to local storage
                  await _localStorage.saveMessage(message);
                  
                  messages.add(message);
                } catch (e) {
                  print('ChatService: Error processing message document ${doc.id}: $e');
                }
              }
              
              // Sort by timestamp (newest first)
              messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              
              if (!controller.isClosed) {
                controller.add(messages);
              }
              
            } catch (e) {
              print('ChatService: Error processing messages snapshot: $e');
              // If there's an error, fall back to local storage
              await loadLocalMessages();
            }
          },
          onError: (error) {
            print('ChatService: Error listening to Firestore messages: $error');
            // On error, fall back to local storage
            loadLocalMessages();
          },
        );
        
        // Also load local messages immediately
        await loadLocalMessages();
        
      } catch (e) {
        print('ChatService: Error setting up Firestore listener: $e');
        // Fall back to local storage
        await loadLocalMessages();
      }
    }
    
    // Initial setup
    setupFirestoreListener();
    
    // Handle controller disposal
    controller.onCancel = () {
      print('ChatService: Messages stream cancelled for chat $chatId');
      firestoreSubscription?.cancel();
      _messageControllers.remove(chatId);
    };
    
    return controller.stream;
  }
  
  // Método para crear o obtener un chat existente con otro usuario
Future<ChatModel?> createOrGetChat(String otherUserId) async {
  try {
    final userId = await getCurrentUserId();
    if (userId == null) {
      print('ChatService: No current user ID available');
      return null;
    }
    
    print('ChatService: Creating or getting chat with user: $otherUserId');
    
    // Verificar si ya existe un chat con este usuario
    final existingChat = await _findExistingChat(otherUserId);
    if (existingChat != null) {
      print('ChatService: Found existing chat: ${existingChat.id}');
      return existingChat;
    }
    
    // Verificar conectividad antes de crear un nuevo chat
    final isOnline = await _connectivityService.checkConnectivity();
    if (!isOnline) {
      print('ChatService: Cannot create new chat while offline');
      return null;
    }
    
    print('ChatService: No existing chat found, creating new chat');
    
    // Crear nuevo chat en Firestore
    try {
      final newChatRef = _firestore.collection('chats').doc();
      
      // Crear estructura del documento del chat
      await newChatRef.set({
        'participants': [userId, otherUserId],
        'hasUnreadMessages': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
      
      print('ChatService: New chat created successfully with ID: ${newChatRef.id}');
      
      // Crear modelo de chat local
      final newChat = ChatModel(
        id: newChatRef.id,
        participants: [userId, otherUserId],
        hasUnreadMessages: false,
        lastMessageTime: DateTime.now(),
      );
      
      // Guardar en almacenamiento local
      await _localStorage.saveChat(newChat);
      
      // Precargar datos del otro usuario
      _userService.getUserById(otherUserId).then((user) {
        if (user != null) {
          _userCache[otherUserId] = user;
          print('ChatService: Preloaded user data for chat participant');
        }
      });
      
      return newChat;
    } catch (e) {
      print('ChatService: Error creating new chat in Firestore: $e');
      return null;
    }
  } catch (e) {
    print('ChatService: Error in createOrGetChat: $e');
    return null;
  }
}



// Método auxiliar para encontrar un chat existente
Future<ChatModel?> _findExistingChat(String otherUserId) async {
  try {
    final userId = await getCurrentUserId();
    if (userId == null) return null;
    
    // Primero buscar en el almacenamiento local
    final localChats = await _localStorage.getAllChats();
    for (final chat in localChats) {
      // Verificar si los participantes coinciden con ambos usuarios
      if (chat.participants.contains(userId) && 
          chat.participants.contains(otherUserId) && 
          chat.participants.length == 2) {
        print('ChatService: Found existing chat in local storage: ${chat.id}');
        return chat;
      }
    }
    
    // Si no está en local y hay conexión, buscar en Firestore
    final isOnline = await _connectivityService.checkConnectivity();
    if (!isOnline) {
      print('ChatService: Offline, cannot search for existing chat in Firestore');
      return null;
    }
    
    // Buscar en Firestore
    final snapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .get();
    
    for (final doc in snapshot.docs) {
      final chatData = doc.data();
      final participants = List<String>.from(chatData['participants'] ?? []);
      
      // Verificar si el otro usuario es participante y son solo 2 usuarios
      if (participants.contains(otherUserId) && participants.length == 2) {
        final chat = ChatModel.fromFirestore(chatData, doc.id);
        
        // Guardar en almacenamiento local
        await _localStorage.saveChat(chat);
        
        print('ChatService: Found existing chat in Firestore: ${doc.id}');
        return chat;
      }
    }
    
    // No se encontró chat existente
    return null;
  } catch (e) {
    print('ChatService: Error finding existing chat: $e');
    return null;
  }
}

  // Send a message with offline queueing
  Future<bool> sendMessage(String chatId, String text) async {
    try {
      // Ensure message text is not empty
      if (text.trim().isEmpty) {
        print('ChatService: Cannot send empty message');
        return false;
      }
      
      // Get current user ID
      final userId = await getCurrentUserId();
      if (userId == null) {
        print('ChatService: Cannot send message - no current user');
        return false;
      }
      
      // Create message object
      final now = DateTime.now();
      final messageId = 'local_${now.millisecondsSinceEpoch}_$userId';
      
      final message = MessageModel(
        id: messageId,
        chatId: chatId,
        senderId: userId,
        text: text,
        timestamp: now,
      );
      
      // Save message locally first
      await _localStorage.saveMessage(message);
      
      // Update chat with last message info
      final chat = await _localStorage.getChat(chatId);
      if (chat != null) {
        final updatedChat = ChatModel(
          id: chat.id,
          participants: chat.participants,
          lastMessage: text,
          lastMessageTime: now,
          lastMessageSenderId: userId,
          hasUnreadMessages: true,
          additionalData: chat.additionalData,
        );
        
        await _localStorage.saveChat(updatedChat);
      }
      
      // Check connectivity
      final isOnline = await _connectivityService.checkConnectivity();
      if (!isOnline) {
        print('ChatService: Device is offline, message queued for later sending');
        
        // In a production app, you would set up a background sync task here
        // to send queued messages when connectivity is restored
        
        return true; // Locally successful
      }
      
      // Send to Firestore
      try {
        // Create a new message document
        final messageRef = _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc();
        
        // Use server timestamp for better consistency
        await messageRef.set({
          'senderId': userId,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Update chat document with last message info
        await _firestore.collection('chats').doc(chatId).update({
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': userId,
        });
        
        print('ChatService: Message sent to Firestore');
        return true;
      } catch (firestoreError) {
        print('ChatService: Error sending message to Firestore: $firestoreError');
        
        // Still return true since the message was saved locally
        return true;
      }
    } catch (e) {
      print('ChatService: Error sending message: $e');
      return false;
    }
  }
  
  // Mark chat as read with offline support
  Future<bool> markChatAsRead(String chatId) async {
    try {
      // Get current user ID
      final userId = await getCurrentUserId();
      if (userId == null) {
        print('ChatService: Cannot mark chat as read - no current user');
        return false;
      }
      
      // Update locally first
      await _localStorage.updateChatUnreadStatus(chatId, false);
      
      // Check connectivity
      final isOnline = await _connectivityService.checkConnectivity();
      if (!isOnline) {
        print('ChatService: Device is offline, chat marked as read locally only');
        return true;
      }
      
      // Update in Firestore
      try {
        await _firestore.collection('chats').doc(chatId).update({
          'unreadFor': FieldValue.arrayRemove([userId]),
        });
        
        print('ChatService: Chat marked as read in Firestore');
        return true;
      } catch (firestoreError) {
        print('ChatService: Error marking chat as read in Firestore: $firestoreError');
        
        // Still return true since the chat was marked as read locally
        return true;
      }
    } catch (e) {
      print('ChatService: Error marking chat as read: $e');
      return false;
    }
  }
  
  // Get chat participant with caching
  Future<UserModel?> getChatParticipant(String chatId) async {
    try {
      // Get chat data
      final chat = await _localStorage.getChat(chatId);
      if (chat == null) {
        print('ChatService: Cannot get participant - chat not found');
        return null;
      }
      
      // Get current user ID
      final userId = await getCurrentUserId();
      if (userId == null) {
        print('ChatService: Cannot get participant - no current user');
        return null;
      }
      
      // Find the other participant
      String? otherUserId;
      for (final participantId in chat.participants) {
        if (participantId != userId) {
          otherUserId = participantId;
          break;
        }
      }
      
      if (otherUserId == null) {
        print('ChatService: Cannot get participant - no other participant found');
        return null;
      }
      
      // Check cache first
      if (_userCache.containsKey(otherUserId)) {
        final cachedUser = _userCache[otherUserId];
        if (cachedUser != null) {
          print('ChatService: Using cached user data for ${cachedUser.displayName}');
          return cachedUser;
        }
      }
      
      // Get user data from service
      final user = await _userService.getUserById(otherUserId);
      
      // Update cache
      if (user != null) {
        _userCache[otherUserId] = user;
        print('ChatService: Added user ${user.displayName} to cache');
      }
      
      return user;
    } catch (e) {
      print('ChatService: Error getting chat participant: $e');
      return null;
    }
  }
  
  // Fix chat sender IDs for consistency
  Future<void> fixChatSenderIds(String chatId) async {
    try {
      // Check connectivity
      final isOnline = await _connectivityService.checkConnectivity();
      if (!isOnline) {
        print('ChatService: Cannot fix chat sender IDs while offline');
        return;
      }
      
      print('ChatService: Fixing lastMessageSenderId for chat $chatId');
      
      // Get the most recent message
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (messagesSnapshot.docs.isEmpty) {
        print('ChatService: No messages found for chat $chatId');
        return;
      }
      
      final latestMessage = messagesSnapshot.docs.first;
      final senderId = latestMessage.data()['senderId'];
      
      if (senderId == null) {
        print('ChatService: Latest message has no senderId');
        return;
      }
      
      // Update chat document with correct lastMessageSenderId
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessageSenderId': senderId,
      });
      
      print('ChatService: Updated lastMessageSenderId to $senderId');
      
      // Also update local storage
      final chat = await _localStorage.getChat(chatId);
      if (chat != null) {
        final updatedChat = ChatModel(
          id: chat.id,
          participants: chat.participants,
          lastMessage: chat.lastMessage,
          lastMessageTime: chat.lastMessageTime,
          lastMessageSenderId: senderId,
          hasUnreadMessages: chat.hasUnreadMessages,
          additionalData: chat.additionalData,
        );
        
        await _localStorage.saveChat(updatedChat);
      }
    } catch (e) {
      print('ChatService: Error fixing chat sender IDs: $e');
    }
  }
  
  // Perform maintenance tasks (call periodically)
  Future<void> performMaintenance() async {
    try {
      print('ChatService: Performing maintenance tasks');
      
      // Compress old messages to save storage space
      await _localStorage.compressOldMessages(30); // Keep last 30 days
      
      // Clear user cache to free memory
      _userCache.clear();
      
      print('ChatService: Maintenance tasks completed');
    } catch (e) {
      print('ChatService: Error during maintenance: $e');
    }
  }
}