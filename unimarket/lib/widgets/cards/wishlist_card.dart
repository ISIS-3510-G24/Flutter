// wishlist_card.dart
import 'package:flutter/cupertino.dart';
import 'package:unimarket/theme/app_colors.dart';

class WishlistCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const WishlistCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _buildPlaceholderImage(size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_forward,
              color: CupertinoColors.systemGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.transparentGrey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Icon(CupertinoIcons.photo, size: 20, color: CupertinoColors.white),
      ),
    );
  }
}
