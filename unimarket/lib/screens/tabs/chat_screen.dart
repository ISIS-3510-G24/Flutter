// lib/screens/tabs/chat_screen.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unimarket/models/chat_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/screens/chat/chat_detail_screen.dart';
import 'package:unimarket/services/chat_service.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";
  List<ChatModel> _chats = [];
  Map<String, UserModel?> _chatUsers = {};
  bool _isDisposed = false;
  StreamSubscription? _chatSubscription;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _chatSubscription?.cancel();
    _loadingTimer?.cancel();
    super.dispose();
  }

Future<void> _loadChats() async {
  if (_isDisposed) return;
  
  setState(() {
    _isLoading = true;
    _hasError = false;
    _errorMessage = "";
  });

  try {
    // Verificar que haya un usuario actual
    final currentUserId = _chatService.currentUserId;
    if (currentUserId == null) {
      print('ChatScreen: No hay usuario actual (currentUserId es null)');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "No se pudo cargar los chats. Usuario no autenticado.";
      });
      return;
    }
    
    print('ChatScreen: Usuario actual: $currentUserId');
    
    // Cancelar suscripción existente si la hay
    await _chatSubscription?.cancel();
    
    // Crear una nueva suscripción
    _chatSubscription = _chatService.getUserChats().listen(
      (chats) async {
        if (_isDisposed) return;
        
        print('ChatScreen: Se recibieron ${chats.length} chats');
        _chats = chats;
        
        // Cargar detalles de usuario para cada chat
        for (final chat in _chats) {
          if (!_chatUsers.containsKey(chat.id) || _chatUsers[chat.id] == null) {
            print('ChatScreen: Cargando usuario para chat ${chat.id}');
            try {
              // Verificar participantes
              if (chat.participants.isEmpty) {
                print('ChatScreen: Chat ${chat.id} no tiene participantes');
                continue;
              }
              
              // Verificar si el usuario actual está en los participantes
              if (!chat.participants.contains(currentUserId)) {
                print('ChatScreen: El usuario actual no está en los participantes del chat ${chat.id}');
                continue;
              }
              
              final user = await _chatService.getChatParticipant(chat.id);
              if (user == null) {
                print('ChatScreen: No se pudo obtener el usuario para chat ${chat.id}');
              } else {
                print('ChatScreen: Usuario obtenido para chat ${chat.id}: ${user.displayName}');
              }
              
              if (mounted && !_isDisposed) {
                setState(() {
                  _chatUsers[chat.id] = user;
                });
              }
            } catch (e) {
              print('ChatScreen: Error al cargar usuario para chat ${chat.id}: $e');
            }
          }
        }
        
        if (mounted && !_isDisposed) {
          setState(() {
            _isLoading = false;
          });
        }
        
        // Cancelar el temporizador de tiempo de espera
        _loadingTimer?.cancel();
      },
      onError: (error) {
        print("ChatScreen: Error al escuchar los chats: $error");
        if (mounted && !_isDisposed) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = "No se pudieron cargar los chats. $error";
          });
        }
        
        _loadingTimer?.cancel();
      },
    );

    // Establecer un temporizador de tiempo de espera
    _loadingTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_isDisposed && _isLoading) {
        print('ChatScreen: Tiempo de espera para cargar chats');
        setState(() {
          _isLoading = false;
          if (_chats.isEmpty) {
            _hasError = true;
            _errorMessage = "Tiempo de espera agotado. Verifica tu conexión.";
          }
        });
      }
    });
  } catch (e) {
    print("ChatScreen: Error al configurar el oyente de chat: $e");
    if (mounted && !_isDisposed) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "No se pudo conectar al servicio de chat. $e";
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Messages",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _hasError
                ? _buildErrorState()
                : _chats.isEmpty
                    ? _buildEmptyState()
                    : _buildChatList(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle,
            color: CupertinoColors.systemRed,
            size: 60,
          ),
          const SizedBox(height: 20),
          Text(
            "Could not load messages",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Please try again later. Our team has been notified.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          const SizedBox(height: 30),
          CupertinoButton(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            child: Text(
              "Try Again",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
            onPressed: _loadChats,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            "assets/svgs/EmptyChat.svg",
            height: 150,
            width: 150,
          ),
          const SizedBox(height: 20),
          Text(
            "No messages yet",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "When you contact a seller about their product, you'll see your conversations here.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          const SizedBox(height: 30),
          CupertinoButton(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            child: Text(
              "Explore Products",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
            onPressed: () {
              // Navigate to root (tab controller will be there)
              Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

Widget _buildChatList() {
  return ListView.builder(
    itemCount: _chats.length,
    itemBuilder: (context, index) {
      final chat = _chats[index];
      final user = _chatUsers[chat.id];
      
      String displayName = 'Cargando...';
      if (user != null) {
        displayName = user.displayName;
      }
      
      String lastMessage = 'No hay mensajes aún';
      if (chat.lastMessage != null && chat.lastMessage!.isNotEmpty) {
        lastMessage = chat.lastMessage!;
      }
      
      // Añadir un separador después de cada elemento excepto el último
      return Column(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              // Navegar a detalle de chat
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => ChatDetailScreen(
                    chatId: chat.id,
                    otherUser: user,
                  ),
                ),
              ).then((_) {
                // Recargar al volver para actualizar estados de lectura
                if (mounted && !_isDisposed) {
                  _loadChats();
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Avatar de usuario
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CupertinoColors.systemGrey5,
                    ),
                    child: user != null && user.photoURL != null && user.photoURL!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              user.photoURL!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    user.displayName.substring(0, 1).toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Text(
                              user != null ? user.displayName.substring(0, 1).toUpperCase() : '?',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Detalles del chat
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Nombre de usuario
                            Text(
                              displayName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: chat.hasUnreadMessages
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: CupertinoColors.black,
                              ),
                            ),
                            
                            // Marca de tiempo
                            if (chat.lastMessageTime != null)
                              Text(
                                _formatTimestamp(chat.lastMessageTime!),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Último mensaje
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: chat.hasUnreadMessages
                                      ? CupertinoColors.black
                                      : CupertinoColors.systemGrey,
                                  fontWeight: chat.hasUnreadMessages
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            
                            // Indicador de no leído
                            if (chat.hasUnreadMessages)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Añadir separador después de cada elemento excepto el último
          if (index < _chats.length - 1)
            Container(
              height: 1,
              color: CupertinoColors.systemGrey5,
              margin: const EdgeInsets.only(left: 75),
            ),
        ],
      );
    },
  );
}

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 7) {
      return DateFormat('MM/dd/yyyy').format(timestamp);
    } else if (difference.inDays > 0) {
      return DateFormat('EEE').format(timestamp); // Day of week
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }
}