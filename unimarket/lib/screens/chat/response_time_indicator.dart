// lib/widgets/chat/response_time_indicator.dart
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';

class ChatResponseTimeIndicator extends StatelessWidget {
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final String currentUserId;

  const ChatResponseTimeIndicator({
    Key? key,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show for sellers when the last message is from a buyer
    if (lastMessageTime == null || lastMessageSenderId == currentUserId) {
      return const SizedBox.shrink();
    }

    // Calculate days since last message
    final int daysPassed = DateTime.now().difference(lastMessageTime!).inDays;
    
    // Don't show if less than a day has passed
    if (daysPassed < 1) {
      return const SizedBox.shrink();
    }

    // Determine appearance based on days passed
    Color backgroundColor = AppColors.primaryBlue.withOpacity(0.1);
    Color textColor = AppColors.primaryBlue;
    IconData icon = CupertinoIcons.clock;
    String timeText = '$daysPassed ${daysPassed == 1 ? 'day' : 'days'}';
    String messageText = 'This buyer has been waiting for your response.';

    // Change appearance for urgent responses
    if (daysPassed >= 5) {
      backgroundColor = CupertinoColors.systemOrange.withOpacity(0.1);
      textColor = CupertinoColors.systemOrange;
      icon = CupertinoIcons.exclamationmark_circle;
      messageText = 'This buyer has been waiting for a response for a while.';
    }
    
    if (daysPassed >= 7) {
      backgroundColor = CupertinoColors.systemRed.withOpacity(0.1);
      textColor = CupertinoColors.systemRed;
      icon = CupertinoIcons.exclamationmark_triangle;
      messageText = 'Please respond to this buyer as soon as possible.';
    }

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
                  'Waiting for $timeText',
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