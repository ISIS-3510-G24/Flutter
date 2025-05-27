import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/models/offer_model.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:unimarket/services/connectivity_service.dart';

class OfferDetailsScreen extends StatefulWidget {
  final OfferModel offer;

  const OfferDetailsScreen({super.key, required this.offer});

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen> {
  late StreamSubscription<bool> _connectivitySubscription;
  bool _isConnected = true;
  bool _isCheckingConnectivity = false;
  late StreamSubscription<bool> _checkingSubscription;

  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _checkingSubscription.cancel();
    super.dispose();
    super.dispose();
  }

   void _setupConnectivityListener() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen((bool isConnected) {
      setState(() {
        _isConnected = isConnected;
      });
      if (!_isConnected) {
        print("You are offline. Some features may not work.");
      } else {
        print("You are online.");
      }
    });

    _checkingSubscription = _connectivityService.checkingStream.listen((bool isChecking) {
      setState(() {
        _isCheckingConnectivity = isChecking;
      });
    });
  }

  Future<void> _checkInitialConnectivity() async {
    setState(() {
      _isCheckingConnectivity = true;
    });
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = result != ConnectivityResult.none;
      _isCheckingConnectivity = false;
    });
  }

  Widget _buildConnectivityBanner() {
    if (!_isConnected || _isCheckingConnectivity) {
      return Container(
        width: double.infinity,
        color: CupertinoColors.systemYellow.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            _isCheckingConnectivity
                ? const CupertinoActivityIndicator(radius: 8)
                : const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: 16,
                    color: CupertinoColors.systemYellow,
                  ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isCheckingConnectivity
                    ? "Checking internet connection..."
                    : "You are offline. Some features may not work.",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

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
        child: Column(
          children: [
            // Connectivity Banner
            _buildConnectivityBanner(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Offer Image
                    if (widget.offer.image.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: widget.offer.image,
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
                      "\$${widget.offer.price.toStringAsFixed(2)}",
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Offer Description
                    Text(
                      widget.offer.description,
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
                          widget.offer.userName,
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
                      "Posted on: ${_formatDate(widget.offer.timestamp)}",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}