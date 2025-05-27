// lib/screens/product/product_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/screens/profile/user_profile_screen.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/services/product_cache_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/widgets/buttons/contact_seller_button.dart';
import 'package:unimarket/data/firebase_dao.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // Services
  final UserService _userService = UserService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  
  // State variables  
  UserModel? _seller;
  bool _isInWishlist = false;
  bool _isLoading = true;
  bool _hasInternet = true;
  int _currentImageIndex = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  /// Initialize screen with offline-first approach
  Future<void> _initializeScreen() async {
    try {
      print('ProductDetail: Initializing for product ${widget.product.title}');
      
      // Check connectivity
      _hasInternet = await _connectivityService.checkConnectivity();
      print('ProductDetail: Internet available: $_hasInternet');
      
      // Load seller info and wishlist status in parallel
      await Future.wait([
        _loadSellerInfo(),
        _loadWishlistStatus(),
      ]);
      
    } catch (e) {
      print('ProductDetail: Error during initialization: $e');
      _setError('Error loading product details: $e');
    }
  }

  /// Load seller information with offline-first strategy
  Future<void> _loadSellerInfo() async {
    try {
      print('ProductDetail: Loading seller info for ${widget.product.sellerID}');
      
      // Use enhanced UserService which handles offline caching
      final seller = await _userService.getUserById(widget.product.sellerID);
      
      if (seller != null) {
        _seller = seller;
        print('ProductDetail: Seller loaded: ${seller.displayName}');
      } else {
        print('ProductDetail: Seller not found');
        _setError('Seller information not available');
      }
      
    } catch (e) {
      print("ProductDetail: Error loading seller info: $e");
      _setError('Could not load seller information');
    } finally {
      _isLoading = false;
      if (mounted) setState(() {});
    }
  }

  /// Load wishlist status with offline handling
  Future<void> _loadWishlistStatus() async {
    try {
      if (_hasInternet) {
        final isInWishlist = await _firebaseDAO.isProductInWishlist(widget.product.id!)
            .timeout(const Duration(seconds: 5));
        
        setState(() {
          _isInWishlist = isInWishlist;
        });
        
        print('ProductDetail: Wishlist status loaded: $isInWishlist');
      } else {
        print('ProductDetail: Offline - skipping wishlist status check');
      }
    } catch (e) {
      print('ProductDetail: Error loading wishlist status: $e');
      // Don't show error for wishlist - it's not critical
    }
  }

  /// Toggle wishlist with offline handling
  Future<void> _toggleWishlist() async {
    if (!_hasInternet) {
      _showOfflineMessage('Wishlist changes require internet connection');
      return;
    }
    
    try {
      // Optimistic update
      setState(() {
        _isInWishlist = !_isInWishlist;
      });
      
      await _firebaseDAO.toggleWishlist(widget.product.id!, !_isInWishlist);
      print('ProductDetail: Wishlist toggled successfully');
      
    } catch (e) {
      print('ProductDetail: Error toggling wishlist: $e');
      
      // Revert optimistic update
      setState(() {
        _isInWishlist = !_isInWishlist;
      });
      
      _showErrorMessage('Failed to update wishlist');
    }
  }

  /// Set error state
  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    if (mounted) setState(() {});
  }

  /// Show offline message
  void _showOfflineMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Offline'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Show error message
  void _showErrorMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Format price with thousands separators
  String _formatPrice(double price) {
    // Convert to integer to remove decimal part
    int wholePart = price.toInt();
    String priceString = wholePart.toString();
    String result = '';
    
    // Process differently based on number length
    if (priceString.length > 6) {
      // For millions (7+ digits)
      // Add apostrophe after first digit
      result = "${priceString[0]}'";
      
      // Add the rest of the digits with thousands separator
      String remainingDigits = priceString.substring(1);
      for (int i = 0; i < remainingDigits.length; i++) {
        result += remainingDigits[i];
        
        // Add dot after every 3rd digit from the right
        int positionFromRight = remainingDigits.length - 1 - i;
        if (positionFromRight % 3 == 0 && i < remainingDigits.length - 1) {
          result += '.';
        }
      }
    } else {
      // For smaller numbers, just add thousands separators
      for (int i = 0; i < priceString.length; i++) {
        result += priceString[i];
        
        // Add dot after every 3rd digit from the right
        int positionFromRight = priceString.length - 1 - i;
        if (positionFromRight % 3 == 0 && i < priceString.length - 1) {
          result += '.';
        }
      }
    }
    
    // Add dollar sign at the end
    return "$result \$";
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.product.title,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    // Error state
    if (_errorMessage != null && _seller == null) {
      return _buildErrorState();
    }
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Offline indicator
          if (!_hasInternet) _buildOfflineIndicator(),
          
          // Product Images
          _buildProductImages(),

          // Product Title and Price
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.title,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatPrice(widget.product.price),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Contact Seller Button
                ContactSellerButton(
                  sellerId: widget.product.sellerID,
                  productTitle: widget.product.title,
                ),
                
                // Wishlist Heart Icon
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _toggleWishlist,
                  child: Icon(
                    _isInWishlist ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    color: _isInWishlist ? Colors.red : CupertinoColors.systemGrey,
                    size: 28,
                  ),
                )
              ],
            ),
          ),

          // Separator line
          Container(
            height: 1,
            color: CupertinoColors.systemGrey5,
          ),

          // Seller Information
          _buildSellerInfo(),

          // Separator line
          Container(
            height: 1,
            color: CupertinoColors.systemGrey5,
          ),

          // Product Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Description",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.product.description,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: CupertinoColors.black,
                  ),
                ),
              ],
            ),
          ),

          // Labels
          if (widget.product.labels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Labels",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.product.labels.map((label) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Bottom padding
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: CupertinoColors.systemOrange.withOpacity(0.2),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.wifi_slash,
            color: CupertinoColors.systemOrange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            "Offline Mode - Some features may be limited",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: CupertinoColors.systemOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? "Unknown error",
              style: GoogleFonts.inter(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
                _initializeScreen();
              },
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImages() {
    if (widget.product.imageUrls.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        color: CupertinoColors.systemGrey6,
        child: Center(
          child: SvgPicture.asset(
            "assets/svgs/ImagePlaceHolder.svg",
            height: 100,
            width: 100,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Image display with cached network images
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
              return CachedNetworkImage(
                imageUrl: widget.product.imageUrls[index],
                cacheManager: ProductCacheService.productImageCacheManager,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: CupertinoColors.systemGrey6,
                  child: const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: CupertinoColors.systemGrey6,
                  child: Center(
                    child: SvgPicture.asset(
                      "assets/svgs/ImagePlaceHolder.svg",
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Page indicators
        if (widget.product.imageUrls.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.product.imageUrls.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? AppColors.primaryBlue
                        : CupertinoColors.systemGrey.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSellerInfo() {
    return GestureDetector(
      onTap: () {
        if (_seller != null) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => UserProfileScreen(
                userId: _seller!.id,
                initialUserData: _seller, // Pass seller data to avoid reloading
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Seller Avatar with cached network image
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.systemGrey5,
              ),
              child: ClipOval(
                child: _buildSellerAvatar(),
              ),
            ),
            const SizedBox(width: 16),
            
            // Seller Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLoading 
                        ? "Loading..." 
                        : (_seller?.displayName ?? "Unknown Seller"),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
            
            // Navigation indicator
            Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerAvatar() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    
    if (_seller?.photoURL != null && _seller!.photoURL!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _seller!.photoURL!,
        cacheManager: ProductCacheService.productImageCacheManager,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CupertinoActivityIndicator(),
        ),
        errorWidget: (context, url, error) => _buildDefaultAvatar(),
      );
    } else {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        _seller != null
            ? _seller!.displayName.substring(0, 1).toUpperCase()
            : "?",
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }
}