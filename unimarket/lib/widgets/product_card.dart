import 'package:flutter/cupertino.dart';
import 'package:unimarket/theme/app_colors.dart';

class ProductCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPressedBuy;

  const ProductCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.onPressedBuy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildPlaceholderImage(size: 60),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: CupertinoColors.systemGrey)),
                const SizedBox(height: 6),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(18),
                  onPressed: onPressedBuy,
                  child: const Text(
                    "Buy",
                    style: TextStyle(fontSize: 12, color: CupertinoColors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage({double size = 60}) {
    // En tu caso podrías usar una Image.network o Image.asset
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
