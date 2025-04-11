// lib/screens/seller/unanswered_messages_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unimarket/screens/chat/chat_detail_screen.dart';
import 'package:unimarket/services/unanswered_messages_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/models/user_model.dart';

class UnansweredMessagesScreen extends StatefulWidget {
  const UnansweredMessagesScreen({super.key});

  @override
  _UnansweredMessagesScreenState createState() => _UnansweredMessagesScreenState();
}

class _UnansweredMessagesScreenState extends State<UnansweredMessagesScreen> {
  final UnansweredMessagesService _unansweredService = UnansweredMessagesService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _unansweredChats = [];

  @override
  void initState() {
    super.initState();
    _loadUnansweredMessages();
  }

  Future<void> _loadUnansweredMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final unansweredChats = await _unansweredService.getUnansweredMessagesBySeller();
      
      setState(() {
        _unansweredChats = unansweredChats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading unanswered messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Unanswered Messages",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _unansweredChats.isEmpty
                ? _buildEmptyState()
                : _buildUnansweredList(),
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
            "All caught up!",
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
              "You've responded to all your buyer messages.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnansweredList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Text(
            "Buyers waiting for your response:",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: _loadUnansweredMessages,
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chat = _unansweredChats[index];
                    final UserModel buyer = chat['buyer'];
                    final int days = chat['daysSinceLastMessage'];
                    final DateTime lastMessageTime = chat['lastMessageTime'];
                    
                    // Determine urgency color based on days waiting
                    Color urgencyColor = CupertinoColors.systemBlue;
                    if (days >= 7) {
                      urgencyColor = CupertinoColors.systemRed;
                    } else if (days >= 3) {
                      urgencyColor = CupertinoColors.systemOrange;
                    }
                    
                    return Column(
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => ChatDetailScreen(
                                  chatId: chat['chatId'],
                                  otherUser: buyer,
                                ),
                              ),
                            ).then((_) {
                              // Reload on return to update status
                              _loadUnansweredMessages();
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
                                  child: buyer.photoURL != null && buyer.photoURL!.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            buyer.photoURL!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Center(
                                                child: Text(
                                                  buyer.displayName.isNotEmpty 
                                                      ? buyer.displayName.substring(0, 1).toUpperCase() 
                                                      : "?",
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
                                            buyer.displayName.isNotEmpty
                                                ? buyer.displayName.substring(0, 1).toUpperCase()
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
                                            buyer.displayName,
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: CupertinoColors.black,
                                            ),
                                          ),
                                          
                                          // Days waiting indicator
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: urgencyColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              "$days ${days == 1 ? 'day' : 'days'}",
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: urgencyColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      
                                      // Last message
                                      Text(
                                        chat['lastMessage'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                      
                                      // Last message time
                                      Text(
                                        "Last message: ${DateFormat('MMM d, h:mm a').format(lastMessageTime)}",
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Reply button
                                CupertinoButton(
                                  padding: const EdgeInsets.all(8),
                                  color: AppColors.primaryBlue,
                                  borderRadius: BorderRadius.circular(20),
                                  minSize: 0,
                                  child: Text(
                                    "Reply",
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: CupertinoColors.white,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (context) => ChatDetailScreen(
                                          chatId: chat['chatId'],
                                          otherUser: buyer,
                                        ),
                                      ),
                                    ).then((_) {
                                      _loadUnansweredMessages();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Add separator after each item except the last
                        if (index < _unansweredChats.length - 1)
                          Container(
                            height: 1,
                            color: CupertinoColors.systemGrey5,
                            margin: const EdgeInsets.only(left: 75),
                          ),
                      ],
                    );
                  },
                  childCount: _unansweredChats.length,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}