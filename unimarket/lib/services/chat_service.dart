import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/models/chat_model.dart';
import 'package:unimarket/models/message_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/services/user_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  
  // Collection references
  CollectionReference get _chatsCollection => _firestore.collection('chats');
  CollectionReference get chatsCollection => _firestore.collection('chats');

  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Create or get existing chat with another user
  Future<ChatModel?> createOrGetChat(String otherUserId) async {
    if (currentUserId == null) {
      print('No current user ID available');
      return null;
    }
    
    print('Creating or getting chat with user: $otherUserId');
    
    try {
      // Check if chat already exists
      final existingChat = await _findExistingChat(otherUserId);
      if (existingChat != null) {
        print('Found existing chat: ${existingChat.id}');
        return existingChat;
      }
      
      print('No existing chat found, creating new chat');
      
      // Create new chat
      final newChatRef = _chatsCollection.doc();
      
      // Create a proper chat document structure
      await newChatRef.set({
        'participants': [currentUserId!, otherUserId],
        'hasUnreadMessages': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('New chat created successfully with ID: ${newChatRef.id}');
      
      // Return a ChatModel with the new chat data
      return ChatModel(
        id: newChatRef.id,
        participants: [currentUserId!, otherUserId],
        hasUnreadMessages: false,
      );
    } catch (e) {
      print('Error creating or getting chat: $e');
      return null;
    }
  }

  Future<List<MessageModel>> getLocalMessages(String chatId) async {
    // Call private method internally
    return _getLocalMessages(chatId);
  }

  // Find existing chat with another user
  Future<ChatModel?> _findExistingChat(String otherUserId) async {
    if (currentUserId == null) return null;
    
    try {
      print('Searching for existing chat with user $otherUserId');
      
      // Query chats where current user is a participant
      final snapshot = await _chatsCollection
          .where('participants', arrayContains: currentUserId)
          .get();
      
      print('Found ${snapshot.docs.length} chats for current user');
      
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
            print('Chat ${doc.id} participants: $participants');
          }
          
          if (participants.contains(otherUserId)) {
            print('Found matching chat: ${doc.id}');
            return ChatModel.fromFirestore(chatData, doc.id);
          }
        } catch (e) {
          print('Error processing chat ${doc.id}: $e');
          continue;
        }
      }
      
      print('No existing chat found with user $otherUserId');
      return null;
    } catch (e) {
      print('Error finding existing chat: $e');
      return null;
    }
  }
  
// Get all chats for current user
Stream<List<ChatModel>> getUserChats() {
  if (currentUserId == null) {
    return Stream.value([]);
  }
  
  try {
    // Create a StreamController to handle errors
    final controller = StreamController<List<ChatModel>>();
    
    // Obtener datos directamente desde el servidor, no de la caché
    _firestore.collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get(GetOptions(source: Source.server))
        .then((snapshot) {
          try {
            print('Obtenidos ${snapshot.docs.length} chats desde el servidor');
            
            final List<Future<ChatModel>> chatFutures = snapshot.docs.map((doc) async {
              try {
                // Obtener información adicional desde la subcollection de mensajes
                final messagesQuery = await _firestore
                    .collection('chats')
                    .doc(doc.id)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .get();
                
                final Map<String, dynamic> chatData = doc.data();
                
                // Si hay mensajes, obtener el último sender directamente de los mensajes
                if (messagesQuery.docs.isNotEmpty) {
                  final latestMessageData = messagesQuery.docs.first.data();
                  
                  print('Chat ${doc.id} - Último mensaje en subcollection:');
                  print('  SenderId: ${latestMessageData['senderId']}');
                  print('  Texto: ${latestMessageData['text']}');
                  
                  // Actualizar los datos del chat con la información más reciente
                  chatData['lastMessageSenderId'] = latestMessageData['senderId'];
                  chatData['lastMessage'] = latestMessageData['text'];
                  
                  // Corregir el timestamp si es necesario
                  if (latestMessageData['timestamp'] != null) {
                    chatData['lastMessageTime'] = latestMessageData['timestamp'];
                  }
                }
                
                return ChatModel.fromFirestore(chatData, doc.id);
              } catch (e) {
                print('Error al obtener mensajes para chat ${doc.id}: $e');
                return ChatModel.fromFirestore(doc.data(), doc.id);
              }
            }).toList();
            
            // Esperar a que se completen todas las futuras
            Future.wait(chatFutures).then((chats) {
              // Filtrar nulos y ordenar
              final validChats = chats
                  .where((chat) => chat != null)
                  .toList();
              
              // Ordenar por tiempo del último mensaje
              validChats.sort((a, b) {
                if (a.lastMessageTime == null) return 1;
                if (b.lastMessageTime == null) return -1;
                return b.lastMessageTime!.compareTo(a.lastMessageTime!);
              });
              
              // Agregar al stream
              controller.add(validChats);
              
              // Configurar listener para actualizaciones en tiempo real
              final subscription = _chatsCollection
                  .where('participants', arrayContains: currentUserId)
                  .snapshots()
                  .listen(
                    (snapshot) async {
                      try {
                        // Procesar con el mismo método de obtener mensajes recientes
                        final List<Future<ChatModel>> realtimeChatFutures = 
                            snapshot.docs.map((doc) async {
                          try {
                            // Obtener últimos mensajes
                            final messagesQuery = await _firestore
                                .collection('chats')
                                .doc(doc.id)
                                .collection('messages')
                                .orderBy('timestamp', descending: true)
                                .limit(1)
                                .get();
                            
                            final Map<String, dynamic> chatData = 
                                doc.data() as Map<String, dynamic>;
                            
                            // Actualizar con datos del último mensaje
                            if (messagesQuery.docs.isNotEmpty) {
                              final latestMessageData = messagesQuery.docs.first.data();
                              chatData['lastMessageSenderId'] = latestMessageData['senderId'];
                              chatData['lastMessage'] = latestMessageData['text'];
                              
                              if (latestMessageData['timestamp'] != null) {
                                chatData['lastMessageTime'] = latestMessageData['timestamp'];
                              }
                            }
                            
                            return ChatModel.fromFirestore(chatData, doc.id);
                          } catch (e) {
                            print('Error al procesar chat ${doc.id} en tiempo real: $e');
                            return ChatModel.fromFirestore(
                              doc.data() as Map<String, dynamic>, 
                              doc.id
                            );
                          }
                        }).toList();
                        
                        // Esperar que se completen las futuras
                        final realtimeChats = await Future.wait(realtimeChatFutures);
                        
                        // Filtrar y ordenar
                        final validRealtimeChats = realtimeChats
                            .where((chat) => chat != null)
                            .toList();
                        
                        validRealtimeChats.sort((a, b) {
                          if (a.lastMessageTime == null) return 1;
                          if (b.lastMessageTime == null) return -1;
                          return b.lastMessageTime!.compareTo(a.lastMessageTime!);
                        });
                        
                        // Agregar al stream si no está cerrado
                        if (!controller.isClosed) {
                          controller.add(validRealtimeChats);
                        }
                      } catch (e) {
                        print('Error procesando actualizaciones en tiempo real: $e');
                        if (!controller.isClosed) {
                          controller.addError(e);
                        }
                      }
                    },
                    onError: (error) {
                      print('Error en listener de Firestore: $error');
                      if (!controller.isClosed) {
                        controller.addError(error);
                      }
                    },
                  );
              
              // Limpiar suscripción cuando se cancele el stream
              controller.onCancel = () {
                subscription.cancel();
              };
            });
          } catch (e) {
            print('Error procesando chats iniciales: $e');
            controller.addError(e);
          }
        })
        .catchError((error) {
          print('Error al obtener chats de Firestore: $error');
          controller.addError(error);
        });
    
    return controller.stream;
  } catch (e) {
    print('Error en getUserChats: $e');
    return Stream.value([]);
  }
}

  // Get messages for a specific chat
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    try {
      print('Starting message stream for chat $chatId');
      
      // Check if the messages subcollection exists
      _checkAndCreateMessagesCollection(chatId);
      
      // Create a StreamController to handle errors and cache
      final controller = StreamController<List<MessageModel>>();
      
      // First try to load cached messages
      _getLocalMessages(chatId).then((cachedMessages) {
        // Immediately emit cached messages if available
        if (cachedMessages.isNotEmpty) {
          print('Emitting ${cachedMessages.length} cached messages');
          controller.add(cachedMessages);
        } else {
          print('No cached messages available for chat $chatId');
        }
        
        // Set up Firestore subscription with better error handling
        final subscription = _chatsCollection
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots()
            .listen(
              (snapshot) {
                try {
                  print('Message snapshot received for chat $chatId: ${snapshot.docs.length} documents');
                  
                  if (snapshot.docs.isEmpty) {
                    print('No messages in Firestore for chat $chatId');
                    if (!controller.isClosed) {
                      controller.add([]);
                    }
                    return;
                  }
                  
                  final messages = snapshot.docs.map((doc) {
                    try {
                      final data = doc.data();
                      print('Processing message ${doc.id} with data: $data');
                      
                      // Make sure chatId is available in the data
                      if (!data.containsKey('chatId')) {
                        data['chatId'] = chatId;
                      }
                      
                      // Add document ID to data
                      data['id'] = doc.id;
                      
                      return MessageModel.fromFirestore(data, doc.id);
                    } catch (e) {
                      print('Error parsing message ${doc.id}: $e');
                      return null;
                    }
                  })
                  .where((message) => message != null)
                  .cast<MessageModel>()
                  .toList();
                  
                  // Add result to stream if not closed
                  if (!controller.isClosed) {
                    print('Emitting ${messages.length} messages from Firestore');
                    controller.add(messages);
                    
                    // Save messages locally
                    if (messages.isNotEmpty) {
                      _saveMessagesLocally(messages);
                    }
                  }
                } catch (e) {
                  print('Error processing message snapshot: $e');
                  if (!controller.isClosed) {
                    // If we have cached messages, emit those on error
                    if (cachedMessages.isNotEmpty) {
                      controller.add(cachedMessages);
                    } else {
                      controller.addError(e);
                    }
                  }
                }
              },
              onError: (error) {
                print('Firestore error in messages for chat $chatId: $error');
                if (!controller.isClosed) {
                  // If we have cached messages, emit those on error
                  if (cachedMessages.isNotEmpty) {
                    controller.add(cachedMessages);
                  } else {
                    controller.addError(error);
                  }
                }
              },
            );
        
        // Clean up subscription when stream is canceled
        controller.onCancel = () {
          print('Message stream canceled for chat $chatId');
          subscription.cancel();
        };
      });
      
      return controller.stream;
    } catch (e) {
      print('Error setting up message stream for chat $chatId: $e');
      // Return an empty stream on error
      return Stream.value([]);
    }
  }

  // Check if the messages subcollection exists, create sample message if not
  Future<void> _checkAndCreateMessagesCollection(String chatId) async {
    if (currentUserId == null) return;
    
    try {
      print('Checking if messages subcollection exists for chat $chatId');
      
      // Try to get one message to check if subcollection exists
      final messagesQuery = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .limit(1)
          .get();
      
      if (messagesQuery.docs.isEmpty) {
        print('No messages found for chat $chatId. Need to ensure collection exists');
        
        // Check if the chat has a lastMessage field but no messages subcollection
        final chatDoc = await _chatsCollection.doc(chatId).get();
        if (chatDoc.exists) {
          final chatData = chatDoc.data() as Map<String, dynamic>;
          
          if (chatData.containsKey('lastMessage') && chatData['lastMessage'] != null) {
            print('Chat has lastMessage but no messages subcollection. Adding lastMessage as a document');
            
            String lastMessageText = '';
            String? lastMessageSenderId;
            DateTime timestamp = DateTime.now();
            
            // Extract data from the chat document
            if (chatData['lastMessage'] is String) {
              lastMessageText = chatData['lastMessage'];
            }
            
            if (chatData.containsKey('lastMessageSenderId')) {
              lastMessageSenderId = chatData['lastMessageSenderId'];
            }
            
            if (chatData.containsKey('timestamp') || chatData.containsKey('lastMessageTime')) {
              // Use the existing timestamp if available
              dynamic existingTimestamp = chatData['timestamp'] ?? chatData['lastMessageTime'];
              if (existingTimestamp is Timestamp) {
                timestamp = existingTimestamp.toDate();
              }
            }
            
            // Only proceed if we have valid data
            if (lastMessageText.isNotEmpty && lastMessageSenderId != null) {
              // Create a message to ensure the subcollection exists
              await _chatsCollection
                  .doc(chatId)
                  .collection('messages')
                  .add({
                    'chatId': chatId,
                    'senderId': lastMessageSenderId,
                    'text': lastMessageText,
                    'timestamp': timestamp,
                    'isRead': true,
                  });
              
              print('Created message document from lastMessage in chat $chatId');
            }
          }
        }
      } else {
        print('Messages subcollection exists for chat $chatId with at least one document');
      }
    } catch (e) {
      print('Error checking/creating messages subcollection: $e');
    }
  }

  // Helper method to save multiple messages locally
  Future<void> _saveMessagesLocally(List<MessageModel> messages) async {
    if (messages.isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatId = messages.first.chatId;
      final chatKey = 'chat_${chatId}_messages';
      final List<String> messageKeys = prefs.getStringList(chatKey) ?? [];
      
      for (final message in messages) {
        final key = 'chat_${chatId}_${message.id}';
        final messageMap = message.toMap();
        messageMap['id'] = message.id; // Add ID for reconstruction
        
        // Convert DateTime to ISO string
        messageMap['timestamp'] = message.timestamp.toIso8601String();
        
        // Save as JSON string
        await prefs.setString(key, jsonEncode(messageMap));
        
        // Add to message keys if not already present
        if (!messageKeys.contains(key)) {
          messageKeys.add(key);
        }
      }
      
      // Update message keys
      await prefs.setStringList(chatKey, messageKeys);
    } catch (e) {
      print('Error saving messages locally: $e');
    }
  }

// Actualizar en ChatService.dart
Future<void> markChatAsRead(String chatId) async {
  if (currentUserId == null) return;
  
  try {
    // Verificar conectividad primero
    final connectivityService = ConnectivityService();
    final bool isConnected = await connectivityService.checkConnectivity();
    
    print('markChatAsRead - Conectividad: $isConnected');
    
    // Actualizar en Firestore si hay conexión
    if (isConnected) {
      print('markChatAsRead - Actualizando chat $chatId en Firebase');
      
      // Primero actualizar el chat
      await _chatsCollection.doc(chatId).update({
        'hasUnreadMessages': false,
      });
      
      print('markChatAsRead - Chat marcado como leído en Firestore');
      
      // Después actualizar los mensajes individualmente
      try {
        final unreadMessages = await _chatsCollection
            .doc(chatId)
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .where('senderId', isNotEqualTo: currentUserId)
            .get();
        
        print('markChatAsRead - Encontrados ${unreadMessages.docs.length} mensajes no leídos');
        
        if (unreadMessages.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (final doc in unreadMessages.docs) {
            batch.update(doc.reference, {'isRead': true});
          }
          await batch.commit();
          print('markChatAsRead - ${unreadMessages.docs.length} mensajes marcados como leídos');
        }
      } catch (e) {
        print('Error al actualizar mensajes: $e');
        // Continuar con el proceso aunque falle
      }
    } else {
      print('markChatAsRead - Sin conexión, actualizando solo localmente');
    }
    
    // Actualizar en el almacenamiento local
    final prefs = await SharedPreferences.getInstance();
    final chatKey = 'chat_${chatId}';
    final chatJson = prefs.getString(chatKey);
    
    if (chatJson != null) {
      try {
        final chatData = jsonDecode(chatJson) as Map<String, dynamic>;
        chatData['hasUnreadMessages'] = false;
        await prefs.setString(chatKey, jsonEncode(chatData));
        print('markChatAsRead - Chat actualizado localmente');
      } catch (e) {
        print('Error actualizando chat localmente: $e');
      }
    }
    
  } catch (e) {
    print('Error general en markChatAsRead: $e');
  }
}

  // Get user details for a chat participant
  Future<UserModel?> getChatParticipant(String chatId) async {
    try {
      print('Getting participant for chat $chatId');
      // First, ensure we have a current user
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        print('No current user to compare against chat participants');
        return null;
      }
      
      // Get the chat document
      final chatDoc = await _chatsCollection.doc(chatId).get();
      if (!chatDoc.exists) {
        print('Chat $chatId does not exist');
        return null;
      }
      
      final chatData = chatDoc.data() as Map<String, dynamic>;
      
      // Extract participants properly
      List<String> participants = [];
      try {
        if (chatData.containsKey('participants') && chatData['participants'] is List) {
          participants = List<String>.from(
            (chatData['participants'] as List).map((item) => item.toString())
          );
          print('Found participants: $participants');
        } else {
          print('No participants found or invalid format');
          return null;
        }
      } catch (e) {
        print('Error extracting participants: $e');
        return null;
      }
      
      // Check if there are participants
      if (participants.isEmpty) {
        print('Empty participants list');
        return null;
      }
      
      // Filter out the current user to find other participants
      final otherParticipants = participants.where((id) => id != currentUserId).toList();
      
      if (otherParticipants.isEmpty) {
        print('No other participants found in chat - current user: $currentUserId');
        return null;
      }
      
      // Get the first other participant (typically in a 1:1 chat)
      final otherUserId = otherParticipants.first;
      print('Other user ID: $otherUserId');
      
      // Get user info
      final userModel = await _userService.getUserById(otherUserId);
      if (userModel == null) {
        print('Could not fetch user info for $otherUserId');
      } else {
        print('User retrieved: ${userModel.displayName}');
      }
      
      return userModel;
    } catch (e) {
      print('Error in getChatParticipant: $e');
      return null;
    }
  }

  Future<void> _saveMessageLocally(MessageModel message) async {
    try {
      print('Saving message locally: ${message.id}');
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_${message.chatId}_${message.id}';
      
      // Prepare map for JSON
      final messageJson = message.toMap();
      messageJson['id'] = message.id; // Add ID for reconstruction
      
      // Convert DateTime to ISO string
      messageJson['timestamp'] = message.timestamp.toIso8601String();
      
      // Save as JSON string
      final jsonString = jsonEncode(messageJson);
      print('Message JSON to save: $jsonString');
      await prefs.setString(key, jsonString);
      
      // Update chat message keys
      final chatKey = 'chat_${message.chatId}_messages';
      final List<String> messageKeys = prefs.getStringList(chatKey) ?? [];
      if (!messageKeys.contains(key)) {
        messageKeys.add(key);
        await prefs.setStringList(chatKey, messageKeys);
        print('Keys updated, total: ${messageKeys.length}');
      }
    } catch (e) {
      print('Error saving message locally: $e');
    }
  }

  Future<List<MessageModel>> _getLocalMessages(String chatId) async {
    try {
      print('Getting local messages for chat $chatId');
      final prefs = await SharedPreferences.getInstance();
      final chatKey = 'chat_${chatId}_messages';
      final List<String> messageKeys = prefs.getStringList(chatKey) ?? [];
      print('Message keys found: ${messageKeys.length}');
      
      final List<MessageModel> messages = [];
      
      for (final key in messageKeys) {
        final messageString = prefs.getString(key);
        if (messageString != null) {
          try {
            // Properly decode JSON
            final messageMap = jsonDecode(messageString) as Map<String, dynamic>;
            
            // Make sure the chatId is set
            if (!messageMap.containsKey('chatId')) {
              messageMap['chatId'] = chatId;
            }
            
            // Handle timestamp in a safer way
            DateTime timestamp;
            if (messageMap.containsKey('timestamp') && messageMap['timestamp'] != null) {
              if (messageMap['timestamp'] is String) {
                timestamp = DateTime.parse(messageMap['timestamp']);
              } else {
                // Fallback to current time if we can't parse
                timestamp = DateTime.now();
              }
            } else {
              timestamp = DateTime.now();
            }
            
            messages.add(MessageModel(
              id: messageMap['id'] ?? key.split('_').last,
              chatId: messageMap['chatId'] ?? chatId,
              senderId: messageMap['senderId'] ?? '',
              text: messageMap['text'] ?? '',
              timestamp: timestamp,
              isRead: messageMap['isRead'] ?? false,
            ));
          } catch (e) {
            print('Error parsing local message: $e');
          }
        }
      }
      
      // Sort by timestamp (newest first)
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      print('Retrieved ${messages.length} local messages');
      
      return messages;
    } catch (e) {
      print('Error getting local messages: $e');
      return [];
    }
  }


  Future<bool> needsResponseReminder(String chatId) async {
  final messages = await getChatMessages(chatId).first;
  if (messages.isEmpty) return false;
  
  final lastMessage = messages.first; // Assuming sorted newest first
  final currentUserId = _auth.currentUser?.uid;
  
  // If last message is from someone else and older than 5 days
  return lastMessage.senderId != currentUserId && 
         DateTime.now().difference(lastMessage.timestamp).inDays >= 5;
}



  // Send message with improved error handling and structure
  Future<bool> sendMessage(String chatId, String text) async {
    if (currentUserId == null) {
      print('No current user to send message');
      return false;
    }
    
    try {
      print('Sending message to chat $chatId: "$text"');
      
      // Check if chat exists
      final chatDoc = await _chatsCollection.doc(chatId).get();
      if (!chatDoc.exists) {
        print('Chat $chatId does not exist');
        return false;
      }
      
      // Create message document in the proper subcollection
      final timestamp = DateTime.now();
      
      // Create the message data
      final messageData = {
        'chatId': chatId,
        'senderId': currentUserId,
        'text': text,
        'timestamp': timestamp,
        'isRead': false,
      };
      
      // Add the message to the messages subcollection
      final messageRef = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .add(messageData);
      
      print('Created message document with ID: ${messageRef.id}');
      
      // Update chat's last message info
      final chatUpdate = {
        'lastMessage': text,
        'lastMessageTime': timestamp,
        'lastMessageSenderId': currentUserId,
        'hasUnreadMessages': true,
      };
      
      await _chatsCollection.doc(chatId).update(chatUpdate);
      print('Updated chat document with new message info');
      
      // Create MessageModel for local storage
      final message = MessageModel(
        id: messageRef.id,
        chatId: chatId,
        senderId: currentUserId!,
        text: text,
        timestamp: timestamp,
      );
      
      // Save to local storage
      await _saveMessageLocally(message);
      
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }
}