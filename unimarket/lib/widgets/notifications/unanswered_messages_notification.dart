// lib/widgets/notifications/unanswered_messages_notification.dart
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/chat/unanswered_messages_screen.dart';
import 'package:unimarket/services/unanswered_messages_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class UnansweredMessagesNotification extends StatefulWidget {
  const UnansweredMessagesNotification({super.key});

  @override
  State<UnansweredMessagesNotification> createState() => _UnansweredMessagesNotificationState();
}

class _UnansweredMessagesNotificationState extends State<UnansweredMessagesNotification> {
  final UnansweredMessagesService _unansweredService = UnansweredMessagesService();
  bool _isLoading = true;
  int _unansweredCount = 0;
  int _longWaitingCount = 0;

  @override
  void initState() {
    super.initState();
    _checkUnansweredMessages();
  }

  Future<void> _checkUnansweredMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all unanswered messages
      final unansweredChats = await _unansweredService.getUnansweredMessagesBySeller();
      
      // Get long waiting buyers (5+ days)
      final longWaitingBuyers = await _unansweredService.getLongWaitingBuyers(minDays: 5);
      
      setState(() {
        _unansweredCount = unansweredChats.length;
        _longWaitingCount = longWaitingBuyers.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking unanswered messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if there are no unanswered messages
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_unansweredCount == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const UnansweredMessagesScreen(),
          ),
        ).then((_) {
          _checkUnansweredMessages();
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _longWaitingCount > 0 
              ? CupertinoColors.systemOrange.withOpacity(0.15)
              : CupertinoColors.systemBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _longWaitingCount > 0 
                ? CupertinoColors.systemOrange.withOpacity(0.3)
                : CupertinoColors.systemBlue.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _longWaitingCount > 0 
                  ? CupertinoIcons.exclamationmark_circle_fill
                  : CupertinoIcons.chat_bubble_2_fill,
              color: _longWaitingCount > 0 
                  ? CupertinoColors.systemOrange
                  : AppColors.primaryBlue,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _longWaitingCount > 0
                        ? "Urgent: $_longWaitingCount ${_longWaitingCount == 1 ? 'buyer has' : 'buyers have'} been waiting 5+ days"
                        : "$_unansweredCount ${_unansweredCount == 1 ? 'buyer is' : 'buyers are'} waiting for your response",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _longWaitingCount > 0 
                          ? CupertinoColors.systemOrange
                          : AppColors.primaryBlue,
                    ),
                  ),
                  Text(
                    "Tap to view and respond",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: _longWaitingCount > 0 
                  ? CupertinoColors.systemOrange
                  : AppColors.primaryBlue,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}