import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/data/hive_chat_storage.dart';
import 'package:unimarket/data/hive_user_storage.dart';
import 'package:unimarket/models/chat_model.dart';
import 'package:unimarket/models/message_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/services/user_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final HiveChatStorage _chatStorage = HiveChatStorage();
  final HiveUserStorage _userStorage = HiveUserStorage();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Constructor asegurando la inicialización de Hive
  ChatService() {
    _ensureHiveInitialized();
  }
  
  Future<void> _ensureHiveInitialized() async {
    try {
      await HiveChatStorage.initialize();
      await HiveUserStorage.initialize();
      print('ChatService: Hive inicializado correctamente');
    } catch (e) {
      print('ChatService: Error al inicializar Hive: $e');
    }
  }
  
  // Collection references
  CollectionReference get _chatsCollection => _firestore.collection('chats');
  CollectionReference get chatsCollection => _firestore.collection('chats');
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Create or get existing chat with another user
  Future<ChatModel?> createOrGetChat(String otherUserId) async {
    if (currentUserId == null) {
      print('ChatService: No current user ID available');
      return null;
    }
    
    print('ChatService: Creating or getting chat with user: $otherUserId');
    
    try {
      // Check if chat already exists
      final existingChat = await _findExistingChat(otherUserId);
      if (existingChat != null) {
        print('ChatService: Found existing chat: ${existingChat.id}');
        return existingChat;
      }
      
      print('ChatService: No existing chat found, creating new chat');
      
      // Create new chat
      final newChatRef = _chatsCollection.doc();
      
      // Create a proper chat document structure
      await newChatRef.set({
        'participants': [currentUserId!, otherUserId],
        'hasUnreadMessages': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('ChatService: New chat created successfully with ID: ${newChatRef.id}');
      
      // Return a ChatModel with the new chat data
      final newChat = ChatModel(
        id: newChatRef.id,
        participants: [currentUserId!, otherUserId],
        hasUnreadMessages: false,
      );
      
      // Save the new chat to local storage
      await _chatStorage.saveChat(newChat);
      
      // Asegurarse de que los datos de usuario estén en caché
      await _cacheUserData(otherUserId);
      
      return newChat;
    } catch (e) {
      print('ChatService: Error creating or getting chat: $e');
      return null;
    }
  }

  // Find existing chat with another user
  Future<ChatModel?> _findExistingChat(String otherUserId) async {
    if (currentUserId == null) return null;
    
    try {
      print('ChatService: Searching for existing chat with user $otherUserId');
      
      // Query chats where current user is a participant
      final snapshot = await _chatsCollection
          .where('participants', arrayContains: currentUserId)
          .get();
      
      print('ChatService: Found ${snapshot.docs.length} chats for current user');
      
      // Check each chat to see if the other user is also a participant
      for (final doc in snapshot.docs) {
        try {
          final chatData = doc.data() as Map<String, dynamic>;
          
          // Extract participants safely
          List<String> participants = [];
          if (chatData['participants'] is List) {
            participants = List<String>.from(
              (chatData['participants'] as List).map((item) => item.toString())
            );
            print('ChatService: Chat ${doc.id} participants: $participants');
          }
          
          if (participants.contains(otherUserId)) {
            print('ChatService: Found matching chat: ${doc.id}');
            final chatModel = ChatModel.fromFirestore(chatData, doc.id);
            
            // Save to local storage
            await _chatStorage.saveChat(chatModel);
            
            // Asegurarse de que los datos de usuario estén en caché
            await _cacheUserData(otherUserId);
            
            return chatModel;
          }
        } catch (e) {
          print('ChatService: Error processing chat ${doc.id}: $e');
          continue;
        }
      }
      
      print('ChatService: No existing chat found with user $otherUserId');
      return null;
    } catch (e) {
      print('ChatService: Error finding existing chat: $e');
      return null;
    }
  }
  
  // Get all chats for current user
  Stream<List<ChatModel>> getUserChats() {
    if (currentUserId == null) {
      print('ChatService: getUserChats - No current user ID');
      return Stream.value([]);
    }
    
    try {
      // Create a StreamController to handle errors
      final controller = StreamController<List<ChatModel>>();
      
      // First try to load chats from cache
      _loadCachedChats().then((cachedChats) {
        // Emit cached chats first (if available)
        if (cachedChats.isNotEmpty) {
          print('ChatService: Emitting ${cachedChats.length} cached chats');
          controller.add(cachedChats);
          
          // Asegurarse de que los datos de usuario estén en caché para todos los chats
          for (var chat in cachedChats) {
            _cacheParticipantsData(chat.participants);
          }
        }
        
        // Check connectivity before fetching from Firestore
        _connectivityService.checkConnectivity().then((isConnected) {
          if (isConnected) {
            print('ChatService: Device is connected, fetching from Firestore');
            
            // Fetch from Firestore with server option
            _firestore.collection('chats')
                .where('participants', arrayContains: currentUserId)
                .get(GetOptions(source: Source.server))
                .then((snapshot) async {
                  try {
                    print('ChatService: Got ${snapshot.docs.length} chats from server');
                    final List<ChatModel> chats = await _processChatsSnapshot(snapshot);
                    
                    // Add processed chats to stream
                    if (!controller.isClosed) {
                      controller.add(chats);
                      
                      // Asegurarse de que los datos de usuario estén en caché para todos los chats
                      for (var chat in chats) {
                        _cacheParticipantsData(chat.participants);
                      }
                      
                      // Set up real-time listener for changes after initial load
                      _setupChatRealTimeListener(controller, chats);
                    }
                  } catch (e) {
                    print('ChatService: Error in initial chats load: $e');
                    // If we have cached chats, use them instead of showing error
                    if (cachedChats.isNotEmpty && !controller.isClosed) {
                      controller.add(cachedChats);
                    } else if (!controller.isClosed) {
                      controller.addError(e);
                    }
                  }
                })
                .catchError((error) {
                  print('ChatService: Error fetching chats from Firestore: $error');
                  // If we have cached chats, use them instead of showing error
                  if (cachedChats.isNotEmpty && !controller.isClosed) {
                    controller.add(cachedChats);
                  } else if (!controller.isClosed) {
                    controller.addError(error);
                  }
                });
          } else {
            print('ChatService: Device is offline, using only cached chats');
            // If not connected, only use cached chats
            if (!controller.isClosed) {
              // Add a timeout to simulate network request
              Future.delayed(Duration(milliseconds: 500), () {
                if (!controller.isClosed) {
                  controller.add(cachedChats);
                }
              });
            }
          }
        });
      });
      
      return controller.stream;
    } catch (e) {
      print('ChatService: Error in getUserChats: $e');
      return Stream.value([]);
    }
  }
  
  // Load chats from cache
  Future<List<ChatModel>> _loadCachedChats() async {
    try {
      print('ChatService: Loading chats from cache');
      final cachedChats = await _chatStorage.getAllChats();
      print('ChatService: Loaded ${cachedChats.length} chats from cache');
      
      // Sort the chats by last message time
      cachedChats.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      
      return cachedChats;
    } catch (e) {
      print('ChatService: Error loading cached chats: $e');
      return [];
    }
  }
  
  // Cache user data for all participants in a chat
  Future<void> _cacheParticipantsData(List<String> participants) async {
    if (currentUserId == null) return;
    
    for (final userId in participants) {
      if (userId != currentUserId) {
        await _cacheUserData(userId);
      }
    }
  }
  
  // Cache user data for a specific user
  Future<void> _cacheUserData(String userId) async {
    try {
      // Verificar primero si ya tenemos el usuario en caché
      final bool exists = await _userStorage.userExists(userId);
      if (exists) {
        print('ChatService: User $userId already in cache');
        return;
      }
      
      // Obtener datos del usuario desde Firestore
      final user = await _userService.getUserById(userId);
      if (user == null) {
        print('ChatService: Could not get user $userId from Firestore');
        return;
      }
      
      // Guardar en caché
      await _userStorage.saveUser(user);
      print('ChatService: User $userId cached successfully');
    } catch (e) {
      print('ChatService: Error caching user data for $userId: $e');
    }
  }
  
  // Process a Firestore snapshot into ChatModel objects
  Future<List<ChatModel>> _processChatsSnapshot(QuerySnapshot snapshot) async {
    try {
      final List<Future<ChatModel>> chatFutures = snapshot.docs.map((doc) async {
        try {
          // Get the latest message for each chat
          final messagesQuery = await _firestore
              .collection('chats')
              .doc(doc.id)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();
          
          // Start with base chat data
          final Map<String, dynamic> chatData = doc.data() as Map<String, dynamic>;
          
          print('ChatService: Processing chat ${doc.id}:');
          print('  Original hasUnreadMessages: ${chatData['hasUnreadMessages']}');
          print('  Original lastMessageSenderId: ${chatData['lastMessageSenderId']}');
          
          // Update with latest message info
          if (messagesQuery.docs.isNotEmpty) {
            final latestMessageData = messagesQuery.docs.first.data();
            
            print('  Latest message from subcollection:');
            print('    SenderId: ${latestMessageData['senderId']}');
            print('    Text: ${latestMessageData['text']}');
            print('    IsRead: ${latestMessageData['isRead']}');
            
            // Update the chat data with latest message info
            chatData['lastMessageSenderId'] = latestMessageData['senderId'];
            chatData['lastMessage'] = latestMessageData['text'];
            
            // Update unread status if the message is from someone else and not read
            if (latestMessageData['senderId'] != currentUserId && 
                latestMessageData['isRead'] == false) {
              chatData['hasUnreadMessages'] = true;
            }
            
            // Update timestamp
            if (latestMessageData['timestamp'] != null) {
              chatData['lastMessageTime'] = latestMessageData['timestamp'];
            }
            
            // Debugging the updated values
            print('  Updated values:');
            print('    lastMessageSenderId: ${chatData['lastMessageSenderId']}');
            print('    hasUnreadMessages: ${chatData['hasUnreadMessages']}');
            
            // Cache sender data
            if (latestMessageData['senderId'] != null && latestMessageData['senderId'] != currentUserId) {
              await _cacheUserData(latestMessageData['senderId']);
            }
          }
          
          // Create chat model
          final chatModel = ChatModel.fromFirestore(chatData, doc.id);
          
          // Cache user data for all participants
          await _cacheParticipantsData(chatModel.participants);
          
          // Save to local storage
          await _chatStorage.saveChat(chatModel);
          
          return chatModel;
        } catch (e) {
          print('ChatService: Error processing chat ${doc.id}: $e');
          
          // Try to get from cache if Firestore processing fails
          final cachedChat = await _chatStorage.getChat(doc.id);
          if (cachedChat != null) {
            print('ChatService: Retrieved chat ${doc.id} from cache');
            return cachedChat;
          }
          
          return ChatModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        }
      }).toList();
      
      // Wait for all futures to complete
      final chats = await Future.wait(chatFutures);
      
      // Filter and sort
      final validChats = chats.where((chat) => chat != null).toList();
      
      validChats.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      
      // Extra debugging for the final chat list
      for (final chat in validChats) {
        print('ChatService: Final chat data - ${chat.id}:');
        print('  lastMessageSenderId: ${chat.lastMessageSenderId}');
        print('  currentUserId: $currentUserId');
        print('  lastMessageTime: ${chat.lastMessageTime}');
        print('  hasUnreadMessages: ${chat.hasUnreadMessages}');
      }
      
      return validChats;
    } catch (e) {
      print('ChatService: Error processing chats snapshot: $e');
      return [];
    }
  }
  
  // Setup real-time listener for chat updates
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _setupChatRealTimeListener(
    StreamController<List<ChatModel>> controller,
    List<ChatModel> initialChats
  ) {
    return _firestore.collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen(
          (snapshot) async {
            try {
              print('ChatService: Real-time update received for chats');
              final updatedChats = await _processChatsSnapshot(snapshot);
              
              // Add to stream if not closed
              if (!controller.isClosed) {
                controller.add(updatedChats);
              }
            } catch (e) {
              print('ChatService: Error in real-time chat update: $e');
              // On error, use initial chats if available
              if (!controller.isClosed && initialChats.isNotEmpty) {
                controller.add(initialChats);
              } else if (!controller.isClosed) {
                controller.addError(e);
              }
            }
          },
          onError: (error) {
            print('ChatService: Error in Firestore listener: $error');
            // On error, use initial chats if available
            if (!controller.isClosed && initialChats.isNotEmpty) {
              controller.add(initialChats);
            } else if (!controller.isClosed) {
              controller.addError(error);
            }
          },
        );
  }

  // Get messages for a specific chat
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    try {
      print('ChatService: Setting up message stream for chat $chatId');
      
      // Create a StreamController
      final controller = StreamController<List<MessageModel>>();
      
      // First try to load cached messages
      _chatStorage.getChatMessages(chatId).then((cachedMessages) {
        // Emit cached messages if available
        if (cachedMessages.isNotEmpty) {
          print('ChatService: Emitting ${cachedMessages.length} cached messages');
          controller.add(cachedMessages);
        }
        
        // Check connectivity before fetching from Firestore
        _connectivityService.checkConnectivity().then((isConnected) {
          if (isConnected) {
            // Set up Firestore subscription
            final subscription = _chatsCollection
                .doc(chatId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .snapshots()
                .listen(
                  (snapshot) {
                    try {
                      print('ChatService: Message snapshot received with ${snapshot.docs.length} documents');
                      
                      if (snapshot.docs.isEmpty) {
                        print('ChatService: No messages in Firestore for chat $chatId');
                        if (!controller.isClosed) {
                          controller.add([]);
                        }
                        return;
                      }
                      
                      // Process message documents
                      final List<MessageModel> messages = [];
                      
                      for (final doc in snapshot.docs) {
                        try {
                          final data = doc.data();
                          
                          // Make sure chatId is included
                          data['chatId'] = chatId;
                          data['id'] = doc.id;
                          
                          final message = MessageModel.fromFirestore(data, doc.id);
                          messages.add(message);
                          
                          // Save each message to local storage
                          _chatStorage.saveMessage(message);
                          
                          // Cache sender data
                          if (message.senderId != currentUserId) {
                            _cacheUserData(message.senderId);
                          }
                        } catch (e) {
                          print('ChatService: Error parsing message ${doc.id}: $e');
                          // Continue with next message
                        }
                      }
                      
                      // Sort messages by timestamp (newest first)
                      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                      
                      // Add to stream if not closed
                      if (!controller.isClosed) {
                        print('ChatService: Emitting ${messages.length} messages');
                        controller.add(messages);
                      }
                    } catch (e) {
                      print('ChatService: Error processing message snapshot: $e');
                      // Fall back to cache on error
                      if (!controller.isClosed && cachedMessages.isNotEmpty) {
                        controller.add(cachedMessages);
                      } else if (!controller.isClosed) {
                        controller.addError(e);
                      }
                    }
                  },
                  onError: (error) {
                    print('ChatService: Firestore error in message listener: $error');
                    // Fall back to cache on error
                    if (!controller.isClosed && cachedMessages.isNotEmpty) {
                      controller.add(cachedMessages);
                    } else if (!controller.isClosed) {
                      controller.addError(error);
                    }
                  },
                );
            
            // Clean up subscription when stream is canceled
            controller.onCancel = () {
              print('ChatService: Message stream canceled for chat $chatId');
              subscription.cancel();
            };
          } else {
            print('ChatService: Device is offline, using only cached messages');
            // If not connected, only use cached messages
            if (!controller.isClosed && cachedMessages.isNotEmpty) {
              // Add a timeout to simulate network request
              Future.delayed(Duration(milliseconds: 500), () {
                if (!controller.isClosed) {
                  controller.add(cachedMessages);
                }
              });
            } else if (!controller.isClosed) {
              controller.add([]);
            }
          }
        });
      });
      
      return controller.stream;
    } catch (e) {
      print('ChatService: Error setting up message stream: $e');
      return Stream.value([]);
    }
  }

  // Get user details for a chat participant
  Future<UserModel?> getChatParticipant(String chatId) async {
    try {
      print('ChatService: Getting participant for chat $chatId');
      
      if (currentUserId == null) {
        print('ChatService: No current user ID');
        return null;
      }
      
      // Get the chat document
      final chatDoc = await _chatsCollection.doc(chatId).get();
      if (!chatDoc.exists) {
        print('ChatService: Chat $chatId does not exist');
        return null;
      }
      
      final chatData = chatDoc.data() as Map<String, dynamic>;
      
      // Extract participants
      List<String> participants = [];
      try {
        if (chatData.containsKey('participants') && chatData['participants'] is List) {
          participants = List<String>.from(
            (chatData['participants'] as List).map((item) => item.toString())
          );
          print('ChatService: Found participants: $participants');
        } else {
          print('ChatService: No participants found or invalid format');
          return null;
        }
      } catch (e) {
        print('ChatService: Error extracting participants: $e');
        return null;
      }
      
      // Check for empty participants
      if (participants.isEmpty) {
        print('ChatService: Empty participants list');
        return null;
      }
      
      // Filter out current user
      final otherParticipants = participants.where((id) => id != currentUserId).toList();
      
      if (otherParticipants.isEmpty) {
        print('ChatService: No other participants found');
        return null;
      }
      
      // Get the first other participant
      final otherUserId = otherParticipants.first;
      print('ChatService: Other user ID: $otherUserId');
      
      // First try to get from local storage
      UserModel? userModel = await _userStorage.getUser(otherUserId);
      
      // If not in cache, get from Firestore
      if (userModel == null) {
        userModel = await _userService.getUserById(otherUserId);
        
        // Cache the user data
        if (userModel != null) {
          await _userStorage.saveUser(userModel);
        }
      }
      
      if (userModel == null) {
        print('ChatService: Could not fetch user info for $otherUserId');
      } else {
        print('ChatService: User retrieved: ${userModel.displayName}');
      }
      
      return userModel;
    } catch (e) {
      print('ChatService: Error in getChatParticipant: $e');
      return null;
    }
  }

  // Send message
  Future<bool> sendMessage(String chatId, String text) async {
    if (currentUserId == null) {
      print('ChatService: No current user to send message');
      return false;
    }
    
    try {
      print('ChatService: Sending message to chat $chatId: "$text"');
      
      // Check connectivity first
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      // Create message timestamp
      final timestamp = DateTime.now();
      
      // Create message data
      final messageData = {
        'chatId': chatId,
        'senderId': currentUserId,
        'text': text,
        'timestamp': timestamp,
        'isRead': false,
      };
      
      // Create message model for local storage
      final message = MessageModel(
        id: 'local_${timestamp.millisecondsSinceEpoch}_${currentUserId!.substring(0, 8)}',
        chatId: chatId,
        senderId: currentUserId!,
        text: text,
        timestamp: timestamp,
        isRead: false,
      );
      
      // Always save to local storage immediately
      await _chatStorage.saveMessage(message);
      
      if (isConnected) {
        // Check if chat exists
        final chatDoc = await _chatsCollection.doc(chatId).get();
        if (!chatDoc.exists) {
          print('ChatService: Chat $chatId does not exist');
          return false;
        }
        
        // Add message to Firestore
        final messageRef = await _chatsCollection
            .doc(chatId)
            .collection('messages')
            .add(messageData);
        
        print('ChatService: Created message with ID: ${messageRef.id}');
        
        // Update chat document
        final chatUpdate = {
          'lastMessage': text,
          'lastMessageTime': timestamp,
          'lastMessageSenderId': currentUserId,
          // If the message is from current user, the recipient has an unread message
          'hasUnreadMessages': true,
        };
        
        // Use a transaction to update the chat document
        await _firestore.runTransaction((transaction) async {
          transaction.update(
            _chatsCollection.doc(chatId), 
            chatUpdate
          );
        });
        
        print('ChatService: Updated chat with new message info');
        
        // Update local message with server ID
        final serverMessage = MessageModel(
          id: messageRef.id,
          chatId: chatId,
          senderId: currentUserId!,
          text: text,
          timestamp: timestamp,
          isRead: false,
        );
        
        // Save server message to local storage
        await _chatStorage.saveMessage(serverMessage);
        
        // Update chat in local storage
        final existingChat = await _chatStorage.getChat(chatId);
        if (existingChat != null) {
          final updatedChat = ChatModel(
            id: existingChat.id,
            participants: existingChat.participants,
            lastMessage: text,
            lastMessageTime: timestamp,
            lastMessageSenderId: currentUserId,
            hasUnreadMessages: true,
            additionalData: existingChat.additionalData,
          );
          
          await _chatStorage.saveChat(updatedChat);
        }
      } else {
        print('ChatService: Device is offline, message saved only locally');
        // Update chat in local storage with pending message
        final existingChat = await _chatStorage.getChat(chatId);
        if (existingChat != null) {
          final updatedChat = ChatModel(
            id: existingChat.id,
            participants: existingChat.participants,
            lastMessage: text + " (pending)",
            lastMessageTime: timestamp,
            lastMessageSenderId: currentUserId,
            hasUnreadMessages: true,
            additionalData: existingChat.additionalData,
          );
          
          await _chatStorage.saveChat(updatedChat);
        }
      }
      
      return true;
    } catch (e) {
      print('ChatService: Error sending message: $e');
      return false;
    }
  }
  
  // Mark chat as read
  Future<void> markChatAsRead(String chatId) async {
    if (currentUserId == null) return;
    
    try {
      print('ChatService: Marking chat $chatId as read');
      
      // Check connectivity
      final bool isConnected = await _connectivityService.checkConnectivity();
      
      if (isConnected) {
        print('ChatService: Connected - updating in Firestore');
        
        // Update chat document
        await _chatsCollection.doc(chatId).update({
          'hasUnreadMessages': false,
        });
        
        // Update all unread messages sent by others
        try {
          final unreadMessages = await _chatsCollection
              .doc(chatId)
              .collection('messages')
              .where('isRead', isEqualTo: false)
              .where('senderId', isNotEqualTo: currentUserId)
              .get();
          
          print('ChatService: Found ${unreadMessages.docs.length} unread messages to mark as read');
          
          if (unreadMessages.docs.isNotEmpty) {
            final batch = _firestore.batch();
            for (final doc in unreadMessages.docs) {
              batch.update(doc.reference, {'isRead': true});
            }
            await batch.commit();
            print('ChatService: All unread messages marked as read');
          }
        } catch (e) {
          print('ChatService: Error updating unread messages: $e');
        }
      } else {
        print('ChatService: Not connected - updating only locally');
      }
      
      // Update local storage
      await _chatStorage.updateChatUnreadStatus(chatId, false);
      
    } catch (e) {
      print('ChatService: Error in markChatAsRead: $e');
    }
  }
  
  // Manually fix lastMessageSenderId for a chat
  Future<bool> fixChatSenderIds(String chatId) async {
    try {
      print('ChatService: Attempting to fix lastMessageSenderId for chat $chatId');
      
      // Get the chat document
      final chatDoc = await _chatsCollection.doc(chatId).get();
      if (!chatDoc.exists) {
        print('ChatService: Chat $chatId does not exist');
        return false;
      }
      
      // Get the latest message
      final latestMessage = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (latestMessage.docs.isEmpty) {
        print('ChatService: No messages found for chat $chatId');
        return false;
      }
      
      // Get sender ID from latest message
      final latestMessageData = latestMessage.docs.first.data();
      final String senderId = latestMessageData['senderId'];
      
      print('ChatService: Latest message senderId: $senderId');
      
      // Update chat document
      await _chatsCollection.doc(chatId).update({
        'lastMessageSenderId': senderId,
      });
      
      // Also update in local storage
      final existingChat = await _chatStorage.getChat(chatId);
      if (existingChat != null) {
        final updatedChat = ChatModel(
          id: existingChat.id,
          participants: existingChat.participants,
          lastMessage: existingChat.lastMessage,
          lastMessageTime: existingChat.lastMessageTime,
          lastMessageSenderId: senderId,
          hasUnreadMessages: existingChat.hasUnreadMessages,
          additionalData: existingChat.additionalData,
        );
        
        await _chatStorage.saveChat(updatedChat);
      }
      
      // Cache user data for sender
      await _cacheUserData(senderId);
      
      print('ChatService: Updated lastMessageSenderId to $senderId');
      return true;
    } catch (e) {
      print('ChatService: Error fixing chat sender IDs: $e');
      return false;
    }
  }
  
  // Check if a message needs a response reminder
  bool needsResponseReminder(MessageModel message) {
    if (message.senderId == currentUserId) {
      return false; // No reminder needed for our own messages
    }
    
    final daysSinceMessage = DateTime.now().difference(message.timestamp).inDays;
    return daysSinceMessage >= 1; // Show reminder after 1+ days
  }
}