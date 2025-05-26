import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/models/offer_model.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OfferDetailsScreen extends StatelessWidget {
  final OfferModel offer;

  const OfferDetailsScreen({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Offer Details",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        previousPageTitle: "Offers",
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Offer Image
              if (offer.image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: offer.image,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CupertinoActivityIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      CupertinoIcons.photo,
                      size: 40,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Offer Price
              Text(
                "\$${offer.price.toStringAsFixed(2)}",
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 8),

              // Offer Description
              Text(
                offer.description,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 16),

              // Offer User Information
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.person_circle_fill,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    offer.userName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Timestamp
              Text(
                "Posted on: ${_formatDate(offer.timestamp)}",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}