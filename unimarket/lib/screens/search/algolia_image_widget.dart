import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      // No hay imágenes disponibles
      imageWidget = _buildPlaceholder();
    } else {
      String imageUrl = imageUrls.first;
      
      // Manejar tipos de URL
      if (imageUrl.startsWith('content://')) {
        // Las URIs de contenido no son compatibles directamente
        print('ADVERTENCIA: URI de contenido no soportada: $imageUrl');
        imageWidget = _buildPlaceholder();
      } else if (imageUrl.startsWith('http')) {
        // URL de red
        imageWidget = Image.network(
          imageUrl,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            print('Error cargando imagen: $error');
            return _buildPlaceholder();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / 
                      loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        );
      } else {
        // Intentar como URL de red de todos modos
        imageWidget = Image.network(
          imageUrl,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        );
      }
    }

    // Aplicar el borderRadius si se proporciona
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
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