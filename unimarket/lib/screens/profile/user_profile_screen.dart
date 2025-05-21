import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';

class UserProfileScreen extends StatefulWidget {
  
  final String userId;
  final UserModel? initialUserData; // Optional initial data to avoid loading

  const UserProfileScreen({
    super.key, 
    required this.userId,
    this.initialUserData,
  });

  @override
  UserProfileScreenState createState() => UserProfileScreenState();
}

class UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseInAppMessaging fiam = FirebaseInAppMessaging.instance;
  UserModel? user;
  final UserService _userService = UserService();
  List<ProductModel> userProducts = [];
  bool isLoading = true;
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  @override
  void initState() {
    super.initState();
    // Use the initial user data if provided, otherwise load from Firebase
    if (widget.initialUserData != null) {
      user = widget.initialUserData;
      _loadUserProducts();
    } else {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _firebaseDAO.getUserById(widget.userId);

      if (mounted) {
        setState(() {
          user = userData;
        });

        // After user data is loaded, load their products
        _loadUserProducts();

        // Si se completa el hasGreatReviews, mandar el mensaje a in app messaging
        bool hasGreatReviews = await _firebaseDAO.checkSellerReviews(widget.userId);
        if (hasGreatReviews) {
          fiam.triggerEvent('great_reviews');
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserProducts() async {
  try {
    final productMaps = await _firebaseDAO.getProductsByUserId(widget.userId);
    print("Productos crudos: $productMaps"); // Debug: revisa qué retorna la consulta
    final loadedProducts = productMaps.map((map) => ProductModel.fromMap(map)).toList();
    if (mounted) {
      setState(() {
        userProducts = loadedProducts;
        isLoading = false;
      });
    }
  } catch (e) {
    print("Error loading user products: $e");
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "User Profile",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: isLoading
            ? Center(child: CupertinoActivityIndicator())
            : user == null
                ? Center(
                    child: Text(
                      "User not found",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Profile Header
                        _buildProfileHeader(),
                        
                        // User Stats
                        _buildUserStats(),
                        
                        // User Products Section
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "Products",
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // User Product Grid
                        _buildProductsGrid(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // User Avatar
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryBlue,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                    ? Image.network(
                        user!.photoURL!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultAvatar(large: true);
                        },
                      )
                    : _buildDefaultAvatar(large: true),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // User Name
          Text(
            user?.displayName ?? "Unknown User",
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // User Email
          Text(
            user?.email ?? "",
            style: GoogleFonts.inter(
              fontSize: 16,
              color: CupertinoColors.systemGrey,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),

            // User Bio
          Text(
              user?.bio ?? "",
              style: GoogleFonts.inter(
              fontSize: 16,
              color: CupertinoColors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            
          // User Major and Join Date
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightGreyBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user?.major ?? "No Major",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "• Joined ${_formatDate(user?.createdAt ?? DateTime.now())}",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(userProducts.length.toString(), "Products"),
          _buildStatItem(user?.ratingAverage?.toStringAsFixed(1) ?? "N/A", "Rating"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: CupertinoColors.systemGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsGrid() {
    if (userProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              
              const SizedBox(height: 16),
              Text(
                "No products yet",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: userProducts.length,
      itemBuilder: (context, index) {
        final product = userProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return GestureDetector(
      onTap: () {
        // Navigate to product detail
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                width: double.infinity,
                color: CupertinoColors.systemGrey6,
                child: product.imageUrls.isNotEmpty
                    ? Image.network(
                        product.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: SvgPicture.asset(
                              "assets/svgs/ImagePlaceHolder.svg",
                              height: 40,
                              width: 40,
                            ),
                          );
                        },
                      )
                    : Center(
                        child: SvgPicture.asset(
                          "assets/svgs/ImagePlaceHolder.svg",
                          height: 40,
                          width: 40,
                        ),
                      ),
              ),
            ),
            
            // Product Info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    product.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Price
                  Text(
                    _formatPrice(product.price),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: product.status == "Available" 
                          ? AppColors.primaryBlue.withOpacity(0.2) 
                          : CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      product.status,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: product.status == "Available" 
                            ? AppColors.primaryBlue 
                            : CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar({bool large = false}) {
    return Container(
      width: large ? 100 : 30,
      height: large ? 100 : 30,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          user?.displayName.isNotEmpty == true
              ? user!.displayName[0].toUpperCase()
              : "?",
          style: GoogleFonts.inter(
            fontSize: large ? 40 : 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
    );
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

  String _formatDate(DateTime date) {
    // Format as Month Year
    String month = _getMonthName(date.month);
    return "$month ${date.year}";
  }
  
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}