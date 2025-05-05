// lib/screens/search/algolia_image_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductImageWidget extends StatelessWidget {
  final List<String> imageUrls;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final String placeholderAsset;

  const ProductImageWidget({
    Key? key,
    required this.imageUrls,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholderAsset = "assets/svgs/ImagePlaceHolder.svg",
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imageUrls.isEmpty) {
      imageWidget = _buildPlaceholder();
    } else {
      final url = imageUrls.first;
      if (url.startsWith('http')) {
        imageWidget = CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: fit,
          placeholder: (_, __) => SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (_, __, ___) => _buildPlaceholder(),
        );
      } else {
        imageWidget = _buildPlaceholder();
      }
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }
    return imageWidget;
  }

  Widget _buildPlaceholder() {
    if (placeholderAsset.endsWith('.svg')) {
      return SvgPicture.asset(
        placeholderAsset,
        fit: fit,
        width: width,
        height: height,
      );
    } else {
      return Image.asset(
        placeholderAsset,
        fit: fit,
        width: width,
        height: height,
      );
    }
  }
}
