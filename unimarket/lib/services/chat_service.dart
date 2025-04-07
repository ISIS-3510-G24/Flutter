// lib/services/chat_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unimarket/models/chat_model.dart';
import 'package:unimarket/models/message_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/services/user_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  
  // Collection references
  CollectionReference get _chatsCollection => _firestore.collection('chats');
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Create or get existing chat with another user
  Future<ChatModel?> createOrGetChat(String otherUserId) async {
    if (currentUserId == null) return null;
    
    // Check if chat already exists
    final existingChat = await _findExistingChat(otherUserId);
    if (existingChat != null) {
      return existingChat;
    }
    
    // Create new chat
    try {
      final newChatRef = _chatsCollection.doc();
      final newChat = ChatModel(
        id: newChatRef.id,
        participants: [currentUserId!, otherUserId],
      );
      
      await newChatRef.set(newChat.toMap());
      return newChat;
    } catch (e) {
      print('Error creating chat: $e');
      return null;
    }
  }

Future<List<MessageModel>> getLocalMessages(String chatId) async {
  // Llama al método privado internamente
  return _getLocalMessages(chatId);
}
  // Find existing chat with another user
  Future<ChatModel?> _findExistingChat(String otherUserId) async {
    if (currentUserId == null) return null;
    
    try {
      final snapshot = await _chatsCollection
          .where('participants', arrayContains: currentUserId)
          .get();
          
      for (final doc in snapshot.docs) {
        try {
          final chatData = doc.data() as Map<String, dynamic>;
          final participants = List<String>.from(chatData['participants'] ?? []);
          
          if (participants.contains(otherUserId)) {
            return ChatModel.fromFirestore(chatData, doc.id);
          }
        } catch (e) {
          print('Error processing chat ${doc.id}: $e');
          continue;
        }
      }
      
      return null;
    } catch (e) {
      print('Error finding existing chat: $e');
      return null;
    }
  }
  
  // Get all chats for current user - Modified to work without composite index
  Stream<List<ChatModel>> getUserChats() {
    if (currentUserId == null) {
      return Stream.value([]);
    }
    
    try {
      // Create a StreamController to handle errors
      final controller = StreamController<List<ChatModel>>();
      
      // Subscribe to the Firestore query
      final subscription = _chatsCollection
          .where('participants', arrayContains: currentUserId)
          .snapshots()
          .listen(
            (snapshot) {
              try {
                final chats = snapshot.docs
                    .map((doc) {
                      try {
                        return ChatModel.fromFirestore(
                          doc.data() as Map<String, dynamic>, 
                          doc.id
                        );
                      } catch (e) {
                        print('Error parsing chat ${doc.id}: $e');
                        return null;
                      }
                    })
                    .where((chat) => chat != null)
                    .cast<ChatModel>()
                    .toList();
                
                // Sort the chats manually in memory instead of in the query
                chats.sort((a, b) {
                  if (a.lastMessageTime == null) return 1;
                  if (b.lastMessageTime == null) return -1;
                  return b.lastMessageTime!.compareTo(a.lastMessageTime!);
                });
                
                // Add the result to the stream
                controller.add(chats);
              } catch (e) {
                print('Error processing chats: $e');
                controller.addError(e);
              }
            },
            onError: (error) {
              print('Firestore error: $error');
              controller.addError(error);
            },
          );
      
      // Clean up the subscription when the stream is canceled
      controller.onCancel = () {
        subscription.cancel();
      };
      
      return controller.stream;
    } catch (e) {
      print('Error getting user chats: $e');
      // Return an empty stream with error handling
      return Stream.value([]);
    }
  }

Stream<List<MessageModel>> getChatMessages(String chatId) {
  try {
    print('Iniciando stream de mensajes para chat $chatId');
    // Crear un StreamController para manejar errores y caché
    final controller = StreamController<List<MessageModel>>();
    
    // Primero intentar cargar mensajes en caché
    _getLocalMessages(chatId).then((cachedMessages) {
      // Emitir inmediatamente mensajes en caché si están disponibles
      if (cachedMessages.isNotEmpty) {
        print('Emitiendo ${cachedMessages.length} mensajes en caché');
        controller.add(cachedMessages);
      } else {
        print('No hay mensajes en caché');
      }
      
      // Suscribirse a la consulta de Firestore
      final subscription = _chatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50) // Límite para mejorar rendimiento
          .snapshots()
          .listen(
            (snapshot) {
              try {
                print('Snapshot de mensajes recibido: ${snapshot.docs.length} documentos');
                if (snapshot.docs.isEmpty) {
                  print('No hay mensajes en Firestore');
                  // Si no hay mensajes de Firestore pero tenemos caché, emitimos la caché nuevamente
                  if (cachedMessages.isNotEmpty && !controller.isClosed) {
                    controller.add(cachedMessages);
                  }
                  return;
                }
                
                final messages = snapshot.docs
                    .map((doc) {
                      try {
                        final data = doc.data() as Map<String, dynamic>;
                        // Añadir ID al mapa de datos para mejor construcción de mensajes
                        data['id'] = doc.id;
                        print('Parseando mensaje: ${doc.id}');
                        return MessageModel.fromFirestore(data, doc.id);
                      } catch (e) {
                        print('Error al parsear mensaje ${doc.id}: $e');
                        return null;
                      }
                    })
                    .where((message) => message != null)
                    .cast<MessageModel>()
                    .toList();
                
                // Añadir el resultado al stream
                if (!controller.isClosed) {
                  print('Emitiendo ${messages.length} mensajes de Firestore');
                  controller.add(messages);
                  
                  // Guardar mensajes localmente para acceso sin conexión
                  _saveMessagesLocally(messages);
                }
              } catch (e) {
                print('Error al procesar mensajes: $e');
                // Aún emitir mensajes en caché si hay un error
                if (cachedMessages.isNotEmpty && !controller.isClosed) {
                  print('Emitiendo mensajes en caché después de error');
                  controller.add(cachedMessages);
                } else if (!controller.isClosed) {
                  controller.addError(e);
                }
              }
            },
            onError: (error) {
              print('Error de Firestore en mensajes: $error');
              // Aún emitir mensajes en caché si hay un error
              if (cachedMessages.isNotEmpty && !controller.isClosed) {
                print('Emitiendo mensajes en caché después de error de Firestore');
                controller.add(cachedMessages);
              } else if (!controller.isClosed) {
                controller.addError(error);
              }
            },
          );
      
      // Limpiar la suscripción cuando se cancela el stream
      controller.onCancel = () {
        print('Stream de mensajes cancelado');
        subscription.cancel();
      };
    });
    
    return controller.stream;
  } catch (e) {
    print('Error al obtener mensajes del chat: $e');
    // Devolver mensajes en caché en caso de error si están disponibles
    return Stream.fromFuture(_getLocalMessages(chatId).then((messages) {
      if (messages.isEmpty) {
        print('No hay mensajes en caché para emitir en caso de error');
        throw e; // Lanzar el error si no hay mensajes en caché
      }
      print('Emitiendo ${messages.length} mensajes en caché en caso de error');
      return messages;
    }));
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

  // Mark all messages in a chat as read
  Future<void> markChatAsRead(String chatId) async {
    if (currentUserId == null) return;
    
    try {
      // First update the chat's unread status
      await _chatsCollection.doc(chatId).update({
        'hasUnreadMessages': false,
      });
      
      // Then get all unread messages sent by the other user
      final unreadMessages = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: currentUserId)
          .get();
      
      // Create a batch to update all messages
      if (unreadMessages.docs.isNotEmpty) {
        final batch = _firestore.batch();
        
        for (final doc in unreadMessages.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        
        await batch.commit();
      }
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }
  
  // Get user details for a chat participant
 Future<UserModel?> getChatParticipant(String chatId) async {
  try {
    print('Obteniendo participante para chat $chatId');
    final chatDoc = await _chatsCollection.doc(chatId).get();
    if (!chatDoc.exists) {
      print('El chat $chatId no existe');
      return null;
    }
    
    final chatData = chatDoc.data() as Map<String, dynamic>;
    print('Datos del chat: $chatData');
    
    // Extraer participantes con manejo de errores mejorado
    List<String> participants = [];
    try {
      if (chatData.containsKey('participants') && chatData['participants'] is List) {
        participants = List<String>.from(
          (chatData['participants'] as List).map((item) => item.toString())
        );
        print('Participantes encontrados: $participants');
      } else {
        print('No se encontraron participantes o formato inválido');
      }
    } catch (e) {
      print('Error al extraer participantes: $e');
      return null;
    }
    
    // Verificar si hay participantes
    if (participants.isEmpty) {
      print('Lista de participantes vacía');
      return null;
    }
    
    // Obtener el otro usuario (no el actual)
    String otherUserId = '';
    try {
      otherUserId = participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      print('ID del otro usuario: $otherUserId');
    } catch (e) {
      print('Error al encontrar al otro usuario: $e');
      return null;
    }
    
    if (otherUserId.isEmpty) {
      print('No se encontró otro usuario en el chat');
      return null;
    }
    
    // Obtener el modelo de usuario
    final userModel = await _userService.getUserById(otherUserId);
    print('Usuario obtenido: ${userModel?.toMap()}');
    
    return userModel;
  } catch (e) {
    print('Error al obtener participante del chat: $e');
    return null;
  }
}

Future<void> _saveMessageLocally(MessageModel message) async {
  try {
    print('Guardando mensaje localmente: ${message.id}');
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_${message.chatId}_${message.id}';
    
    // Preparar el mapa para JSON
    final messageJson = message.toMap();
    messageJson['id'] = message.id; // Añadir ID para reconstrucción
    
    // Convertir DateTime a string ISO
    messageJson['timestamp'] = message.timestamp.toIso8601String();
    
    // Guardar como cadena JSON
    final jsonString = jsonEncode(messageJson);
    print('JSON del mensaje a guardar: $jsonString');
    await prefs.setString(key, jsonString);
    
    // Actualizar llaves de mensajes del chat
    final chatKey = 'chat_${message.chatId}_messages';
    final List<String> messageKeys = prefs.getStringList(chatKey) ?? [];
    if (!messageKeys.contains(key)) {
      messageKeys.add(key);
      await prefs.setStringList(chatKey, messageKeys);
      print('Llaves actualizadas, total: ${messageKeys.length}');
    }
  } catch (e) {
    print('Error al guardar mensaje localmente: $e');
  }
}

Future<List<MessageModel>> _getLocalMessages(String chatId) async {
  try {
    print('Obteniendo mensajes locales para chat $chatId');
    final prefs = await SharedPreferences.getInstance();
    final chatKey = 'chat_${chatId}_messages';
    final List<String> messageKeys = prefs.getStringList(chatKey) ?? [];
    print('Llaves de mensajes encontradas: ${messageKeys.length}');
    
    final List<MessageModel> messages = [];
    
    for (final key in messageKeys) {
      final messageString = prefs.getString(key);
      if (messageString != null) {
        try {
          // Decodificar correctamente el JSON
          final messageMap = jsonDecode(messageString) as Map<String, dynamic>;
          print('Mensaje decodificado: $messageMap');
          
          // Extraer timestamp con manejo de errores
          DateTime timestamp = DateTime.now();
          if (messageMap.containsKey('timestamp') && messageMap['timestamp'] != null) {
            try {
              timestamp = DateTime.parse(messageMap['timestamp']);
            } catch (e) {
              print('Error al parsear timestamp: $e');
            }
          }
          
          messages.add(MessageModel(
            id: messageMap['id'] ?? key.split('_').last,
            chatId: chatId,
            senderId: messageMap['senderId'] ?? '',
            text: messageMap['text'] ?? '',
            timestamp: timestamp,
            isRead: messageMap['isRead'] ?? false,
          ));
        } catch (e) {
          print('Error al parsear mensaje local: $e');
        }
      }
    }
    
    // Ordenar por timestamp (más reciente primero)
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    print('Total de mensajes locales recuperados: ${messages.length}');
    
    return messages;
  } catch (e) {
    print('Error al obtener mensajes locales: $e');
    return [];
  }
}

// Corrección 5: Mejorar envío de mensajes
Future<bool> sendMessage(String chatId, String text) async {
  if (currentUserId == null) {
    print('No hay usuario actual para enviar mensaje');
    return false;
  }
  
  try {
    print('Enviando mensaje a chat $chatId: $text');
    // Crear documento de mensaje
    final messageRef = _chatsCollection.doc(chatId).collection('messages').doc();
    final timestamp = DateTime.now();
    final message = MessageModel(
      id: messageRef.id,
      chatId: chatId,
      senderId: currentUserId!,
      text: text,
      timestamp: timestamp,
    );
    
    print('Datos del mensaje a enviar: ${message.toMap()}');
    
    // Actualizar el mensaje y chat en un lote
    final batch = _firestore.batch();
    
    // Añadir el mensaje
    batch.set(messageRef, message.toMap());
    
    // Actualizar el último mensaje del chat
    final chatUpdate = {
      'lastMessage': text,
      'lastMessageTime': timestamp,
      'lastMessageSenderId': currentUserId,
      'hasUnreadMessages': true,
    };
    print('Actualizando chat con: $chatUpdate');
    batch.update(_chatsCollection.doc(chatId), chatUpdate);
    
    await batch.commit();
    print('Mensaje enviado exitosamente');
    
    // Guardar en almacenamiento local
    await _saveMessageLocally(message);
    
    return true;
  } catch (e) {
    print('Error al enviar mensaje: $e');
    return false;
  }
}

}