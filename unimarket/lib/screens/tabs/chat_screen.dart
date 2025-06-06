import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:unimarket/services/auth_storage_service.dart';
import 'package:unimarket/services/image_cache_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unimarket/models/chat_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/screens/chat/chat_detail_screen.dart';
import 'package:unimarket/services/chat_service.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/chat/response_time_indicator.dart';
import 'package:unimarket/services/screen_metrics_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ImageCacheService _imageCacheService = ImageCacheService();
  final UserService _userService = UserService();
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";
  List<ChatModel> _chats = [];
  final Map<String, UserModel?> _chatUsers = {};
  bool _isDisposed = false;
  StreamSubscription? _chatSubscription;
  Timer? _loadingTimer;

  final ScreenMetricsService _metricsService = ScreenMetricsService(); 

  late String _currentuserId;


  @override
  void initState() {
    super.initState();
    _loadChats();
    _metricsService.recordScreenEntry('chat_metrics'); 
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _chatSubscription?.cancel();
    _loadingTimer?.cancel();
    _metricsService.recordScreenExit('chat_metrics'); // Add this
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
      // Check for current user
      // Try to get current user from chat service
      String? currentUserId = await _chatService.getCurrentUserId();
      
      // If null, fall back to cached biometric ID
      //YA NO TOCA ESTO PORQUE EL _chatService.getCurrentUserId(); TIENE OFFLINE SCENARIOS
      /*try{
        currentUserId ??= await BiometricAuthService.getSavedUserID();
      }catch (er){
        _showErrorDialog("There is no uid", "oops");
      }*/
      

      // If still null, show error
      if (currentUserId == null) {
        
        print('ChatScreen: No current user (currentUserId is null)');
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = "Could not load chats. User not authenticated.";
        });
        return;
      }
      _currentuserId = currentUserId;
      
      print('ChatScreen: Loading chats for user: $currentUserId');
      
      // Cancel existing subscription
      await _chatSubscription?.cancel();
      
      // Create a new subscription with error handling
      _chatSubscription = _chatService.getUserChats().listen(
        (chats) async {
          if (_isDisposed) return;
          
          print('ChatScreen: Received ${chats.length} chats');
          
          // Update state with the chats
          setState(() {
            _chats = chats;
          });
          
          // Load user details for each chat
          for (final chat in _chats) {
            if (!_chatUsers.containsKey(chat.id) || _chatUsers[chat.id] == null) {
              print('ChatScreen: Loading user for chat ${chat.id}');
              try {
                // Check for empty participants
                if (chat.participants.isEmpty) {
                  print('ChatScreen: Chat ${chat.id} has no participants');
                  continue;
                }
                
                // Check if current user is in participants
                if (!chat.participants.contains(currentUserId)) {
                  print('ChatScreen: Current user is not in participants for chat ${chat.id}');
                  continue;
                }
                
                // Get the other participant
                final user = await _chatService.getChatParticipant(chat.id);
                if (user == null) {
                  print('ChatScreen: Could not get user for chat ${chat.id}');
                } else {
                  print('ChatScreen: Got user for chat ${chat.id}: ${user.displayName}');
                }
                
                if (mounted && !_isDisposed) {
                  setState(() {
                    _chatUsers[chat.id] = user;
                  });
                }
              } catch (e) {
                print('ChatScreen: Error loading user for chat ${chat.id}: $e');
              }
            }
          }
          
          // Debug chat data again
          for (final chat in _chats) {
            print('------- CHAT DATA ${chat.id} -------');
            print('lastMessageSenderId: ${chat.lastMessageSenderId}');
            print('currentUserId: $currentUserId');
            print('lastMessageTime: ${chat.lastMessageTime}');
            print('hasUnreadMessages: ${chat.hasUnreadMessages}');
            print('lastMessage: ${chat.lastMessage}');
            print('-------------------------------------');
          }
          
          if (mounted && !_isDisposed) {
            setState(() {
              _isLoading = false;
            });
          }
          
          // Cancel timeout timer
          _loadingTimer?.cancel();
        },
        onError: (error) {
          print("ChatScreen: Error listening to chats: $error");
          if (mounted && !_isDisposed) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = "Could not load chats. $error";
            });
          }
          
          _loadingTimer?.cancel();
        },
      );

      // Set a timeout timer
      _loadingTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && !_isDisposed && _isLoading) {
          print('ChatScreen: Timeout loading chats');
          setState(() {
            _isLoading = false;
            if (_chats.isEmpty) {
              _hasError = true;
              _errorMessage = "Request timed out. Check your connection.";
            }
          });
        }
      });
      final List<String> imageUrls = [];
for (final chat in _chats) {
  final user = _chatUsers[chat.id];
  if (user != null && user.photoURL != null && user.photoURL!.isNotEmpty) {
    imageUrls.add(user.photoURL!);
  }
}
if (imageUrls.isNotEmpty) {
  _imageCacheService.precacheImages(imageUrls);
}

    } catch (e) {
      print("ChatScreen: Error setting up chat listener: $e");
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = "Could not connect to chat service. $e";
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
            onPressed: _loadChats,
            child: Text(
              "Try Again",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
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
        
        // Better handling of user name
        String displayName = 'Unknown user';
        
        if (user != null) {
          displayName = user.displayName;
        } else if (_isLoading) {
          displayName = 'Loading...';
        }
        
        String lastMessage = 'No messages yet';
        if (chat.lastMessage != null && chat.lastMessage!.isNotEmpty) {
          lastMessage = chat.lastMessage!;
        }
        
        // Debugging to help identify data issues
        print('Building chat item for ${chat.id}:');
        print('  - User: ${user?.displayName ?? "unknown"}');
        print('  - Last message: $lastMessage');
        print('  - Last message time: ${chat.lastMessageTime}');
        print('  - Last message sender: ${chat.lastMessageSenderId}');
        //print('  - Current user: $currentUserId');
        print('  - Has unread messages: ${chat.hasUnreadMessages}');
        
        // Add separator after each item except the last
        return Column(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                // Navigate to chat detail
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => ChatDetailScreen(
                      chatId: chat.id,
                      otherUser: user,
                    ),
                  ),
                ).then((_) {
                  // Reload on return to update read status
                  if (mounted && !_isDisposed) {
                    _loadChats();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // User avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CupertinoColors.systemGrey5,
                      ),
                      child: user != null && user.photoURL != null && user.photoURL!.isNotEmpty
    ? ClipOval(
        child: _imageCacheService.getOptimizedImageWidget(
          user.photoURL,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholder: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.systemGrey5,
            ),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          errorWidget: Center(
            child: Text(
              user.displayName.isNotEmpty 
                  ? user.displayName.substring(0, 1).toUpperCase() 
                  : "?",
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ),
      )
    : Center(
        child: Text(
          user != null && user.displayName.isNotEmpty
              ? user.displayName.substring(0, 1).toUpperCase()
              : "?",
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
      ),


                    ),
                    const SizedBox(width: 12),
                    
                    // Chat details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Username
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
                              
                              // Timestamp
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
                          
                          // Last message
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
                              
                              // Unread indicator
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
            
            // Response time indicator
            if (chat.lastMessageTime != null && chat.lastMessageSenderId != null)
              ChatResponseTimeIndicator(
                lastMessageTime: chat.lastMessageTime,
                lastMessageSenderId: chat.lastMessageSenderId!,
                currentUserId: _currentuserId,
              ),
            
            // Add separator after each item except the last
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

  void _showErrorDialog(String title, String message) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoButton(
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
}