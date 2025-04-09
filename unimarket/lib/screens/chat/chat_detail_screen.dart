import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unimarket/models/message_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/services/chat_service.dart';
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

  @override
  void initState() {
    super.initState();
    _currentUserId = _chatService.currentUserId;
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
    super.dispose();
  }

  Future<void> _loadChatParticipant() async {
    final user = await _chatService.getChatParticipant(widget.chatId);
    if (mounted) {
      setState(() {
        _otherUser = user;
      });
    }
  }

// Update this method in your ChatDetailScreen class
Future<void> _loadMessages() async {
  setState(() {
    _isLoading = true;
  });

  try {
    print('Loading messages for chat: ${widget.chatId}');
    
    // Set up a timeout to prevent infinite loading
    final timeoutTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        print('Message loading timed out for chat ${widget.chatId}');
        setState(() {
          _isLoading = false;
        });
      }
    });

    // Listen to the messages stream with better error handling
    _chatService.getChatMessages(widget.chatId).listen(
      (messages) {
        timeoutTimer.cancel();
        
        if (mounted) {
          print('Received ${messages.length} messages for chat ${widget.chatId}');
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        timeoutTimer.cancel();
        
        print('Error loading messages for chat ${widget.chatId}: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading messages. Please try again.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
    );
  } catch (e) {
    print('Exception in _loadMessages for chat ${widget.chatId}: $e');
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// Also update _sendMessage method for better handling
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
    print('Sending message to chat ${widget.chatId}: "$messageText"');
    final success = await _chatService.sendMessage(widget.chatId, messageText);
    
    if (mounted) {
      setState(() {
        _isSending = false;
      });
      
      if (!success) {
        print('Failed to send message to chat ${widget.chatId}');
        
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
    print('Error sending message to chat ${widget.chatId}: $e');
    if (mounted) {
      setState(() {
        _isSending = false;
        // Remove optimistic message on error
        _messages = _messages.where((m) => m.id != optimisticMessage.id).toList();
      });
      
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}


  Future<void> _markChatAsRead() async {
    try {
      print('Marking chat ${widget.chatId} as read');
      await _chatService.markChatAsRead(widget.chatId);
    } catch (e) {
      print('Error marking chat as read (handled): $e');
      // Don't show error to user, as this is not critical
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: _otherUser != null
            ? Text(
                _otherUser!.displayName,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              )
            : const Text('Chat'),
        trailing: _otherUser?.photoURL != null
            ? Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(_otherUser!.photoURL!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false, // Allow content to extend behind the bottom safe area
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _messages.isEmpty
                      ? _buildEmptyChat()
                      : _buildMessagesList(),
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
    );
  }

  Widget _buildEmptyChat() {
    return Center(
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
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      print('No messages to display');
      return _buildEmptyChat();
    }
    
    print('Displaying ${_messages.length} messages');
    
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == _currentUserId;
        
        print('Message $index - ID: ${message.id}, Sender: ${message.senderId}, isMe: $isMe');
        
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