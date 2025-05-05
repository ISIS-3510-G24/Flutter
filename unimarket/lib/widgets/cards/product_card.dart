import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/services/product_cache_service.dart';

class ProductCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onPressedBuy;

  const ProductCard({
    Key? key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
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
          _buildImage(size: 60),
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

  Widget _buildImage({double size = 60}) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            width: size,
            height: size,
            cacheManager: ProductCacheService.productImageCacheManager,
            placeholder: (context, url) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.transparentGrey,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: CupertinoActivityIndicator(),
              ),
            ),
            errorWidget: (context, url, error) {
              return _buildPlaceholderImage(size: size);
            },
          ),
        ),
      );
    } else {
      return _buildPlaceholderImage(size: size);
    }
  }

  Widget _buildPlaceholderImage({double size = 60}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.transparentGrey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SvgPicture.asset(
        "assets/svgs/ImagePlaceHolder.svg",
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}