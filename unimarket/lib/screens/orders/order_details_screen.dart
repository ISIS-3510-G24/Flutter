import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/payment/payment_screen.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final ConnectivityService _connectivityService = ConnectivityService();
  late StreamSubscription<bool> _connectivitySubscription;
  late StreamSubscription<bool> _checkingSubscription;

  bool _hasInternetAccess = true;
  bool _isCheckingConnectivity = false;

  @override
  void initState() {
    super.initState();

    _hasInternetAccess = _connectivityService.hasInternetAccess;
    _isCheckingConnectivity = _connectivityService.isChecking;

    _connectivitySubscription = _connectivityService.connectivityStream.listen((hasInternet) {
      if (mounted) {
        setState(() {
          _hasInternetAccess = hasInternet;
        });
      }
    });

    _checkingSubscription = _connectivityService.checkingStream.listen((isChecking) {
      if (mounted) {
        setState(() {
          _isCheckingConnectivity = isChecking;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _checkingSubscription.cancel();
    super.dispose();
  }

  void _handleRetryPressed() async {
    bool hasInternet = await _connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _hasInternetAccess = hasInternet;
      });
    }
  }

  Future<File?> _loadCachedImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl.startsWith('assets/')) {
      return null;
    }
    try {
      final file = await DefaultCacheManager().getSingleFile(imageUrl);
      return file.existsSync() ? file : null;
    } catch (e) {
      return null;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return CupertinoColors.systemGreen;
      case 'purchased':
        return CupertinoColors.systemBlue;
      case 'unpaid':
        return CupertinoColors.systemOrange;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withOpacity(0.9),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
        middle: Text(
          "Order Details",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.black,
          ),
        ),
        previousPageTitle: "Orders",
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.share,
              color: AppColors.primaryBlue,
              size: 18,
            ),
          ),
          onPressed: () {
            // Share functionality
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Connectivity Banner
            if (!_hasInternetAccess || _isCheckingConnectivity)
              _buildConnectivityBanner(),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Product Image Section
                    _buildImageSection(),
                    
                    // Product Info Section
                    _buildProductInfoSection(),
                    
                    // Order Details Section
                    _buildOrderDetailsSection(),
                    
                    // Actions Section
                    _buildActionsSection(),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectivityBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CupertinoColors.systemYellow.withOpacity(0.1),
            CupertinoColors.systemOrange.withOpacity(0.1),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemYellow.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemYellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _isCheckingConnectivity
                ? const CupertinoActivityIndicator(radius: 8)
                : const Icon(
                    CupertinoIcons.wifi_slash,
                    size: 16,
                    color: CupertinoColors.systemYellow,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isCheckingConnectivity
                  ? "Checking connection..."
                  : "You're offline. Some features may not work.",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemYellow.darkColor,
              ),
            ),
          ),
          if (!_isCheckingConnectivity)
            CupertinoButton(
              onPressed: _handleRetryPressed,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minSize: 0,
              borderRadius: BorderRadius.circular(6),
              color: CupertinoColors.systemYellow.withOpacity(0.2),
              child: Text(
                "Retry",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemYellow.darkColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 300,
          color: CupertinoColors.systemGrey6,
          child: FutureBuilder<File?>(
            future: _loadCachedImage(widget.order["image"]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CupertinoActivityIndicator(radius: 20),
                );
              } else if (snapshot.hasError || snapshot.data == null) {
                return _buildImagePlaceholder();
              } else {
                return Image.file(
                  snapshot.data!,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CupertinoColors.systemGrey6,
            CupertinoColors.systemGrey5,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              CupertinoIcons.photo,
              size: 40,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Product Image",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.order['name'] ?? "Unnamed Product",
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.order['price'] ?? "Price not available",
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(widget.order['status'] ?? '').withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.order['status'] ?? "Unknown Status",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(widget.order['status'] ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.info_circle,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Order Information",
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow("Order ID", widget.order['orderId'] ?? "Not available"),
          const SizedBox(height: 16),
          _buildDetailRow("Product ID", widget.order['productId'] ?? "Not available"),
          const SizedBox(height: 16),
          _buildDetailRow("Order Date", _formatOrderDate(widget.order['details'] ?? "")),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    if (widget.order['status'] != "Unpaid") {
      return const SizedBox(height: 20);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          if (!_hasInternetAccess) {
            _showOfflineAlert();
          } else {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => PaymentScreen(
                  productId: widget.order["productId"],
                  orderId: widget.order["orderId"],
                ),
              ),
            );
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryBlue,
                AppColors.primaryBlue.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.creditcard,
                color: CupertinoColors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                "Complete Payment",
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.black,
            ),
          ),
        ),
      ],
    );
  }

  String _formatOrderDate(String details) {
    if (details.contains("Order Date:")) {
      return details.replaceAll("Order Date: ", "");
    }
    return details.isNotEmpty ? details : "Date not available";
  }

  void _showOfflineAlert() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Connection Required"),
        content: const Text("You need an internet connection to complete the payment."),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}