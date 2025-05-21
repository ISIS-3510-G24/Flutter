import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';

class ChatResponseTimeIndicator extends StatelessWidget {
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final String currentUserId;

  const ChatResponseTimeIndicator({
    super.key,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    // Enhanced debugging to track what's happening
    print('ResponseTimeIndicator [${lastMessageSenderId?.substring(0, 5) ?? 'null'}] - Building with:');
    print('  - lastMessageTime: $lastMessageTime');
    print('  - lastMessageSenderId: $lastMessageSenderId');
    print('  - currentUserId: ${currentUserId.substring(0, 5)}...');
    
    // Important check: we ONLY want to show this indicator if the last message
    // is FROM THE OTHER PERSON, not from the current user
    bool isFromOtherUser = lastMessageSenderId != null && lastMessageSenderId != currentUserId;
    print('  - isFromOtherUser: $isFromOtherUser (${isFromOtherUser ? "SHOW INDICATOR" : "DONT SHOW"})');
    
    // Basic validations
    if (lastMessageTime == null) {
      print('  - Not showing: lastMessageTime is null');
      return const SizedBox.shrink();
    }
    
    if (!isFromOtherUser) {
      print('  - Not showing: message was sent by current user or unknown sender');
      return const SizedBox.shrink();
    }

    // Calculate time passed
    final int hoursPassed = DateTime.now().difference(lastMessageTime!).inHours;
    final int daysPassed = hoursPassed ~/ 24; // Integer division
    
    print('  - Time calculation: $hoursPassed hours ($daysPassed days)');
    
    // Only show for messages older than 24 hours
    if (hoursPassed < 24) {
      print('  - Not showing: message is less than 24 hours old');
      return const SizedBox.shrink();
    }
    
    print('  - DISPLAYING INDICATOR for $daysPassed days');

    // Configure appearance based on time passed
    Color backgroundColor = AppColors.primaryBlue.withOpacity(0.1);
    Color textColor = AppColors.primaryBlue;
    IconData icon = CupertinoIcons.clock;
    String timeText = '$daysPassed ${daysPassed == 1 ? 'día' : 'días'}';
    String messageText = 'Este mensaje lleva esperando respuesta.';

    // Change appearance for more urgent responses
    if (daysPassed >= 3 && daysPassed < 7) {
      backgroundColor = CupertinoColors.systemOrange.withOpacity(0.1);
      textColor = CupertinoColors.systemOrange;
      icon = CupertinoIcons.exclamationmark_circle;
      messageText = 'Este mensaje lleva varios días sin respuesta.';
    }
    
    if (daysPassed >= 7) {
      backgroundColor = CupertinoColors.systemRed.withOpacity(0.1);
      textColor = CupertinoColors.systemRed;
      icon = CupertinoIcons.exclamationmark_triangle;
      messageText = 'Este mensaje necesita una respuesta urgentemente.';
    }

    // Build the response time indicator
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: textColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esperando hace $timeText',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  messageText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}