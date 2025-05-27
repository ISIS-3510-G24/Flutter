import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/screens/profile/user_profile_screen.dart';
import 'package:unimarket/screens/payment/payment_screen.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/widgets/buttons/contact_seller_button.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async';
import 'dart:io';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final UserService _userService = UserService();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  UserModel? _seller;
  bool _isInWishlist = false;
  bool _isLoading = true;
  bool _isCreatingOrder = false;
  int _currentImageIndex = 0;
  
  // Connectivity state
  bool _hasInternetAccess = true;
  bool _isCheckingConnectivity = false;
  late StreamSubscription<bool> _connectivitySubscription;
  late StreamSubscription<bool> _checkingSubscription;

  @override
  void initState() {
    super.initState();
    _loadSellerInfo();
    _loadWishlistStatus();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _checkingSubscription.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
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

  void _handleRetryPressed() async {
    bool hasInternet = await _connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _hasInternetAccess = hasInternet;
      });
    }
  }

  Future<File?> _loadCachedImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final file = await DefaultCacheManager().getSingleFile(imageUrl);
      return file.existsSync() ? file : null;
    } catch (e) {
      print("Error loading cached image: $e");
      return null;
    }
  }

  Future<void> _loadSellerInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final seller = await _userService.getUserById(widget.product.sellerID);
      setState(() {
        _seller = seller;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading seller info: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWishlistStatus() async {
    final isInWishlist = await _firebaseDAO.isProductInWishlist(widget.product.id!);
    setState(() {
      _isInWishlist = isInWishlist;
    });
  }

  Future<void> _toggleWishlist() async {
    await _firebaseDAO.toggleWishlist(widget.product.id!, _isInWishlist);
    setState(() {
      _isInWishlist = !_isInWishlist;
    });
  }

  Future<void> _createOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog("Authentication Error", "Please log in to create an order.");
      return;
    }

    print("🔍 Creating order for user: ${user.uid}");
    print("🔍 Product ID: ${widget.product.id}");
    print("🔍 Seller ID: ${widget.product.sellerID}");

    if (!_hasInternetAccess) {
      _showErrorDialog("No Internet Connection", "You need an internet connection to create an order.");
      return;
    }

    // Check if user is trying to buy their own product
    if (user.uid == widget.product.sellerID) {
      _showErrorDialog("Invalid Purchase", "You cannot buy your own product.");
      return;
    }

    setState(() {
      _isCreatingOrder = true;
    });

    try {
      // Create order data
      final orderData = {
        'productID': widget.product.id,
        'buyerID': user.uid,
        'sellerID': widget.product.sellerID,
        'price': widget.product.price,
        'status': 'Unpaid',
        'orderDate': DateTime.now(),
        'createdAt': DateTime.now(),
      };

      print("🔍 Order data prepared: $orderData");

      // Create the order in Firestore
      final orderId = await _firebaseDAO.createOrder(orderData);
      
      print("🔍 Order creation result: $orderId");
      
      if (orderId != null) {
        print("✅ Order created successfully with ID: $orderId");
        // Navigate to payment screen
        if (mounted) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => PaymentScreen(
                productId: widget.product.id!,
                orderId: orderId,
              ),
            ),
          );
        }
      } else {
        _showErrorDialog("Order Creation Failed", "Unable to create order. Please try again.");
      }
    } catch (e) {
      print("🚨 Error creating order: $e");
      _showErrorDialog("Order Creation Failed", "An error occurred while creating your order. Please try again.\n\nError: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOrder = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showOrderConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Create Order"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Are you sure you want to buy this product?"),
            const SizedBox(height: 8),
            Text(
              widget.product.title,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _formatPrice(widget.product.price),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Buy Now"),
            onPressed: () {
              Navigator.pop(ctx);
              _createOrder();
            },
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    int wholePart = price.toInt();
    String priceString = wholePart.toString();
    String result = '';
    
    if (priceString.length > 6) {
      result = "${priceString[0]}'";
      String remainingDigits = priceString.substring(1);
      for (int i = 0; i < remainingDigits.length; i++) {
        result += remainingDigits[i];
        int positionFromRight = remainingDigits.length - 1 - i;
        if (positionFromRight % 3 == 0 && i < remainingDigits.length - 1) {
          result += '.';
        }
      }
    } else {
      for (int i = 0; i < priceString.length; i++) {
        result += priceString[i];
        int positionFromRight = priceString.length - 1 - i;
        if (positionFromRight % 3 == 0 && i < priceString.length - 1) {
          result += '.';
        }
      }
    }
    
    return "$result \$";
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withOpacity(0.9),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
        middle: Text(
          widget.product.title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _toggleWishlist,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isInWishlist 
                ? CupertinoColors.systemRed.withOpacity(0.1)
                : CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isInWishlist ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              color: _isInWishlist ? CupertinoColors.systemRed : CupertinoColors.systemGrey,
              size: 18,
            ),
          ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Images
                    _buildProductImages(),

                    // Product Title and Price
                    _buildProductHeader(),

                    // Separator line
                    Container(
                      height: 1,
                      color: CupertinoColors.separator,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),

                    // Seller Information
                    _buildSellerInfo(),

                    // Separator line
                    Container(
                      height: 1,
                      color: CupertinoColors.separator,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),

                    // Product Description
                    _buildProductDescription(),

                    // Labels
                    if (widget.product.labels.isNotEmpty)
                      _buildProductLabels(),

                    // Bottom padding for floating button
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            
            // Floating Buy Button
            _buildBuyButton(),
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

  Widget _buildProductImages() {
    if (widget.product.imageUrls.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
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
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: CupertinoColors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                CupertinoIcons.photo,
                size: 50,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No Images Available",
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

    return Stack(
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: PageView.builder(
            itemCount: widget.product.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return FutureBuilder<File?>(
                future: _loadCachedImage(widget.product.imageUrls[index]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      color: CupertinoColors.systemGrey6,
                      child: const Center(
                        child: CupertinoActivityIndicator(radius: 15),
                      ),
                    );
                  } else if (snapshot.hasError || snapshot.data == null) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            CupertinoColors.systemGrey6,
                            CupertinoColors.systemGrey5,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            size: 40,
                            color: CupertinoColors.systemGrey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Image Failed to Load",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Image.file(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    );
                  }
                },
              );
            },
          ),
        ),

        if (widget.product.imageUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.product.imageUrls.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? CupertinoColors.white
                        : CupertinoColors.white.withOpacity(0.5),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _formatPrice(widget.product.price),
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryBlue,
                ),
              ),
              const Spacer(),
              ContactSellerButton(
                sellerId: widget.product.sellerID,
                productTitle: widget.product.title,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        if (_seller != null) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => UserProfileScreen(
                userId: _seller!.id,
                initialUserData: _seller,
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.systemGrey5,
              ),
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 12))
                  : _seller?.photoURL != null && _seller!.photoURL!.isNotEmpty
                      ? FutureBuilder<File?>(
                          future: _loadCachedImage(_seller!.photoURL!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CupertinoActivityIndicator(radius: 12));
                            } else if (snapshot.hasError || snapshot.data == null) {
                              return Center(
                                child: Text(
                                  _seller!.displayName.substring(0, 1).toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              );
                            } else {
                              return ClipOval(
                                child: Image.file(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }
                          },
                        )
                      : Center(
                          child: Text(
                            _seller != null
                                ? _seller!.displayName.substring(0, 1).toUpperCase()
                                : "?",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLoading ? "Loading..." : (_seller?.displayName ?? "Unknown Seller"),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.black,
                    ),
                  ),
                  if (_seller?.ratingAverage != null && _seller?.reviewsCount != null)
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.star_fill,
                          color: CupertinoColors.systemYellow,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${_seller!.ratingAverage!.toStringAsFixed(1)} (${_seller!.reviewsCount} reviews)",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey2,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDescription() {
    return Padding(
      padding: const EdgeInsets.all(20),
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
                  CupertinoIcons.doc_text,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Description",
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.product.description,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.5,
              color: CupertinoColors.systemGrey.darkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductLabels() {
    return Padding(
      padding: const EdgeInsets.all(20),
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
                  CupertinoIcons.tag,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Tags",
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.product.labels.map((label) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryBlue,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyButton() {
    final user = FirebaseAuth.instance.currentUser;
    final isOwnProduct = user?.uid == widget.product.sellerID;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: isOwnProduct ? null : (_isCreatingOrder ? null : _showOrderConfirmation),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: isOwnProduct 
                ? null 
                : LinearGradient(
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.primaryBlue.withOpacity(0.8),
                    ],
                  ),
              color: isOwnProduct ? CupertinoColors.systemGrey4 : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isOwnProduct ? [] : [
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
                if (_isCreatingOrder)
                  const CupertinoActivityIndicator(color: CupertinoColors.white)
                else if (isOwnProduct)
                  const Icon(
                    CupertinoIcons.info_circle,
                    color: CupertinoColors.systemGrey,
                    size: 20,
                  )
                else
                  const Icon(
                    CupertinoIcons.cart_badge_plus,
                    color: CupertinoColors.white,
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Text(
                  _isCreatingOrder 
                    ? "Creating Order..."
                    : isOwnProduct 
                      ? "This is Your Product"
                      : "Buy Now",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isOwnProduct 
                      ? CupertinoColors.systemGrey 
                      : CupertinoColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}