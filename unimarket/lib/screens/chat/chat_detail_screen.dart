import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unimarket/models/message_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/screens/profile/user_profile_screen.dart';
import 'package:unimarket/services/chat_service.dart';
import 'package:unimarket/services/image_cache_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final UserModel? otherUser;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    this.otherUser,
  });

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  UserModel? _otherUser;
  String? _currentUserId;
  StreamSubscription? _messagesSubscription;

  @override
void initState() {
  super.initState();
  _initializeState(); 
}

Future<void> _initializeState() async {
  _currentUserId = await _chatService.getCurrentUserId();

  // Reset lastMessageSenderId first
  _fixChatSenderIds();

  // Then load messages and mark as read
  _loadMessages();
  _markChatAsRead();

  // Set the other user from the widget if available
  if (widget.otherUser != null) {
    _otherUser = widget.otherUser;
  } else {
    _loadChatParticipant();
  }
}

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fixChatSenderIds() async {
    try {
      print('ChatDetailScreen: Fixing lastMessageSenderId for chat ${widget.chatId}');
      
      // This will update the lastMessageSenderId field with the correct value from the messages collection
      await _chatService.fixChatSenderIds(widget.chatId);
    } catch (e) {
      print('ChatDetailScreen: Error fixing lastMessageSenderId: $e');
    }
  }


Widget _buildUserAvatar(UserModel? user) {
  final ImageCacheService imageCacheService = ImageCacheService();
  
  if (user == null) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CupertinoColors.systemGrey5,
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.person_fill,
          color: CupertinoColors.systemGrey,
          size: 20,
        ),
      ),
    );
  }
  
  // Si no hay photoURL
  if (user.photoURL == null) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CupertinoColors.systemGrey5,
      ),
      child: Center(
        child: Text(
          user.displayName.isNotEmpty 
              ? user.displayName.substring(0, 1).toUpperCase() 
              : "?",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }
  
  // Usar el servicio de caché para mostrar la imagen
  return ClipOval(
    child: imageCacheService.getOptimizedImageWidget(
      user.photoURL,
      width: 35,
      height: 35,
      fit: BoxFit.cover,
      placeholder: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CupertinoColors.systemGrey5,
        ),
        child: Center(child: CupertinoActivityIndicator()),
      ),
    ),
  );
}
  
  Future<void> _loadChatParticipant() async {
    final user = await _chatService.getChatParticipant(widget.chatId);
    if (mounted) {
      setState(() {
        _otherUser = user;
      });
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('ChatDetailScreen: Loading messages for chat: ${widget.chatId}');
      
      // Cancel any existing subscription
      await _messagesSubscription?.cancel();
      
      // Set up a timeout to prevent infinite loading
      final timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _isLoading) {
          print('ChatDetailScreen: Message loading timed out');
          setState(() {
            _isLoading = false;
          });
        }
      });

      // Listen to the messages stream with better error handling
      _messagesSubscription = _chatService.getChatMessages(widget.chatId).listen(
        (messages) {
          timeoutTimer.cancel();
          
          if (mounted) {
            print('ChatDetailScreen: Received ${messages.length} messages');
            
            // Log message details for debugging
            for (int i = 0; i < messages.length && i < 5; i++) {
              print('Message $i: ID=${messages[i].id}, Text=${messages[i].text}, Sender=${messages[i].senderId}');
            }
            
            setState(() {
              _messages = messages;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          timeoutTimer.cancel();
          
          print('ChatDetailScreen: Error loading messages: $error');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            // Show error message to user
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error loading messages. Please try again.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
      );
    } catch (e) {
      print('ChatDetailScreen: Exception in _loadMessages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _isSending = true;
    });
    
    // Save text and clear input immediately for better UX
    final messageText = text;
    _messageController.clear();
    
    // Create optimistic message for immediate feedback
    final optimisticMessage = MessageModel(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      chatId: widget.chatId,
      senderId: _currentUserId ?? '',
      text: messageText,
      timestamp: DateTime.now(),
    );
    
    // Add optimistic message to list
    setState(() {
      _messages = [optimisticMessage, ..._messages];
    });
    
    try {
      print('ChatDetailScreen: Sending message: "$messageText"');
      final success = await _chatService.sendMessage(widget.chatId, messageText);
      
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        
        if (!success) {
          print('ChatDetailScreen: Failed to send message');
          
          // Remove optimistic message on failure
          setState(() {
            _messages = _messages.where((m) => m.id != optimisticMessage.id).toList();
          });
          
          // Show error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not send message. Please try again.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('ChatDetailScreen: Error sending message: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
          // Remove optimistic message on error
          _messages = _messages.where((m) => m.id != optimisticMessage.id).toList();
        });
        
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error sending message. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _markChatAsRead() async {
    try {
      print('ChatDetailScreen: Marking chat as read');
      await _chatService.markChatAsRead(widget.chatId);
    } catch (e) {
      print('ChatDetailScreen: Error marking chat as read: $e');
      // Don't show error to user, as this is not critical
    }
  }

  Future<void> _refreshMessages() async {
    print('ChatDetailScreen: Refreshing messages');
    await _loadMessages();
  }

  @override
 Widget build(BuildContext context) {
  // Envolver con MaterialApp para proveer MaterialLocalizations
  return Material(
    color: Colors.transparent,
    child: CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: _otherUser != null
            ? Text(
                _otherUser!.displayName,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              )
            : const Text('Chat'),
        trailing: GestureDetector(
  onTap: () {
    if (_otherUser != null) {
      // Navegar al perfil del usuario
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => UserProfileScreen(
            userId: _otherUser!.id,
            initialUserData: _otherUser,
          ),
        ),
      );
    }
  },
  child: _buildUserAvatar(_otherUser),
),
      ),
        child: SafeArea(
          bottom: false, // Allow content to extend behind the bottom safe area
          child: Column(
            children: [
              // Messages list with pull-to-refresh
              Expanded(
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _messages.isEmpty
                        ? _buildEmptyChat()
                        : CupertinoScrollbar(
                            controller: _scrollController,
                            child: RefreshIndicator(
                              onRefresh: _refreshMessages,
                              color: AppColors.primaryBlue,
                              child: _buildMessagesList(),
                            ),
                          ),
              ),
              
              // Message input
              _buildMessageInput(),
              
              // Bottom safe area padding
              MediaQuery.of(context).padding.bottom > 0
                  ? SizedBox(height: MediaQuery.of(context).padding.bottom)
                  : const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    // Allow pull-to-refresh even on empty chat
    return RefreshIndicator(
      onRefresh: _refreshMessages,
      color: AppColors.primaryBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.chat_bubble_2,
                    size: 80,
                    color: CupertinoColors.systemGrey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "No messages yet",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Send a message to start the conversation!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Display most recent messages at the bottom
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _messages.length,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == _currentUserId;
        
        // For debugging issue with message display
        print('Building message: ID=${message.id}, From=${isMe ? "Me" : "Other"}, Text="${message.text}"');
        
        final showTimestamp = index == 0 || 
            _shouldShowTimestamp(_messages[index], _messages[index - 1]);
        
        return Column(
          children: [
            // Timestamp if needed
            if (showTimestamp)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  _formatMessageDate(message.timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
              
            // Message bubble
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primaryBlue : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  message.text,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: isMe ? CupertinoColors.white : CupertinoColors.black,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        border: Border(
          top: BorderSide(
            color: CupertinoColors.systemGrey4.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Message text field
          Expanded(
            child: CupertinoTextField(
              controller: _messageController,
              placeholder: "Type a message...",
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: CupertinoColors.systemGrey4,
                  width: 0.5,
                ),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          
          // Send button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onPressed: _isSending ? null : _sendMessage,
            child: _isSending
                ? const CupertinoActivityIndicator()
                : const Icon(
                    CupertinoIcons.arrow_up_circle_fill,
                    color: AppColors.primaryBlue,
                    size: 30,
                  ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowTimestamp(MessageModel current, MessageModel previous) {
    // Show timestamp if messages are from different days or if there's a gap of more than 30 minutes
    return !_isSameDay(current.timestamp, previous.timestamp) ||
        current.timestamp.difference(previous.timestamp).inMinutes.abs() > 30;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    
    if (_isSameDay(date, now)) {
      return DateFormat('h:mm a').format(date); // Today, show time
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}'; // Yesterday
    } else if (date.isAfter(now.subtract(const Duration(days: 7)))) {
      return DateFormat('EEEE, h:mm a').format(date); // Within a week, show day
    } else {
      return DateFormat('MMM d, h:mm a').format(date); // Older, show date
    }
  }
}