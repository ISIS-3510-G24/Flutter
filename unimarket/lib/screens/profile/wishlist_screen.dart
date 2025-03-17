// lib/screens/tabs/wishlist_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  _WishlistScreenState createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final UserService _userService = UserService();
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  List<Map<String, dynamic>> _wishlistProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
    _trackScreenView();
  }

  // 📊 Track screen view
  void _trackScreenView() {
    analytics.setCurrentScreen(screenName: "WishlistScreen");
  }

  Future<void> _loadWishlist() async {
    setState(() {
      _isLoading = true;
    });

    final products = await _userService.getWishlistProducts();
    
    setState(() {
      _wishlistProducts = products;
      _isLoading = false;
    });
  }

  Future<void> _removeFromWishlist(String productId) async {
    final success = await _userService.removeFromWishlist(productId);
    
    if (success) {
      setState(() {
        _wishlistProducts.removeWhere((product) => product['id'] == productId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "My Wishlist",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _wishlistProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.heart_slash,
                          size: 70,
                          color: CupertinoColors.systemGrey,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Your wishlist is empty",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Save products you're interested in here",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        const SizedBox(height: 30),
                        CupertinoButton(
                          color: AppColors.primaryBlue,
                          child: Text(
                            "Explore Products",
                            style: GoogleFonts.inter(color: CupertinoColors.white),
                          ),
                          onPressed: () {
                            // Navigate to explore/home screen
                            Navigator.of(context, rootNavigator: true).pushNamed('/home');
                          },
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _wishlistProducts.length,
                    itemBuilder: (context, index) {
                      final product = _wishlistProducts[index];
                      return Dismissible(
                        key: Key(product['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: CupertinoColors.systemRed,
                          child: const Icon(
                            CupertinoIcons.delete,
                            color: CupertinoColors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          _removeFromWishlist(product['id']);
                        },
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            // Navigate to product detail
                            Navigator.pushNamed(
                              context,
                              '/product/detail',
                              arguments: {'productID': product['id']},
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: CupertinoColors.systemGrey5),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Product image
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: CupertinoColors.systemGrey6,
                                  ),
                                  child: product['imageUrl'] != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            product['imageUrl'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(
                                                CupertinoIcons.photo,
                                                color: CupertinoColors.systemGrey,
                                                size: 30,
                                              );
                                            },
                                          ),
                                        )
                                      : const Icon(
                                          CupertinoIcons.photo,
                                          color: CupertinoColors.systemGrey,
                                          size: 30,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Product info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'] ?? 'Unknown Product',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product['description'] ?? '',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "\$${product['price']?.toStringAsFixed(2) ?? '0.00'}",
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Heart icon
                                const Icon(
                                  CupertinoIcons.heart_fill,
                                  color: CupertinoColors.systemRed,
                                  size: 22, 
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}