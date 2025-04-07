// lib/widgets/buttons/contact_seller_button.dart
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/screens/chat/chat_detail_screen.dart';
import 'package:unimarket/services/chat_service.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/theme/app_colors.dart';

class ContactSellerButton extends StatefulWidget {
  final String sellerId;
  final String productTitle;

  const ContactSellerButton({
    super.key,
    required this.sellerId,
    required this.productTitle,
  });

  @override
  State<ContactSellerButton> createState() => _ContactSellerButtonState();
}

class _ContactSellerButtonState extends State<ContactSellerButton> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  bool _isLoading = false;
  UserModel? _seller;

  @override
  void initState() {
    super.initState();
    _loadSellerInfo();
  }

  Future<void> _loadSellerInfo() async {
    final seller = await _userService.getUserById(widget.sellerId);
    if (mounted) {
      setState(() {
        _seller = seller;
      });
    }
  }

  Future<void> _contactSeller() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final chat = await _chatService.createOrGetChat(widget.sellerId);
      
      if (chat != null && mounted) {
        // Add an initial message about the product if it's a new chat
        if (chat.lastMessage == null) {
          await _chatService.sendMessage(
            chat.id,
            "Hi, I'm interested in your product: ${widget.productTitle}",
          );
        }
        
        // Navigate to the chat detail screen
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chat.id,
              otherUser: _seller,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error contacting seller: $e');
      
      // Show error alert
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text('Could not start chat. Please try again.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _contactSeller,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primaryBlue),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey4.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_text,
              color: AppColors.primaryBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isLoading ? "Loading..." : "Contact Seller",
              style: GoogleFonts.inter(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}