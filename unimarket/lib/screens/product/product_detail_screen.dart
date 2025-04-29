// lib/screens/product/product_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/screens/profile/user_profile_screen.dart';
import 'package:unimarket/services/user_service.dart';
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
  final UserService _userService = UserService();
  UserModel? _seller;
  bool _isInWishlist = false;
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  bool _isLoading = true;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSellerInfo();
    _loadWishlistStatus();
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
    

  String _formatPrice(double price) {
    // Convert to integer to remove decimal part
    int wholePart = price.toInt();
    String priceString = wholePart.toString();
    String result = '';
    
    // Process differently based on number length
    if (priceString.length > 6) {
      // For millions (7+ digits)
      // Add apostrophe after first digit
      result = priceString[0] + "'";
      
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    // New: Wishlist Heart Icon
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

              // Separator line (Cupertino style)
              Container(
                height: 1,
                color: CupertinoColors.systemGrey5,
              ),

              // Seller Information
              _buildSellerInfo(),

              // Separator line (Cupertino style)
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
        // Image display
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
              return Image.network(
                widget.product.imageUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
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
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: CupertinoColors.systemGrey6,
                    child: const Center(
                      child: CupertinoActivityIndicator(),
                    ),
                  );
                },
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

 
 // En product_detail_screen.dart, modifica el método _buildSellerInfo()
Widget _buildSellerInfo() {
  return GestureDetector(  // Envuelve todo el widget con GestureDetector para hacerlo tocable
    onTap: () {
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Seller Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.systemGrey5,
            ),
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _seller?.photoURL != null && _seller!.photoURL!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _seller!.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                _seller!.displayName.substring(0, 1).toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
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
                      ),
          ),
          const SizedBox(width: 16),
          
          // Seller Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoading ? "Loading..." : (_seller?.displayName ?? "Unknown Seller"),
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
          
          // Agregar un indicador visual de que es tocable
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

}