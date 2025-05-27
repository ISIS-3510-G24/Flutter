import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/services/product_cache_service.dart';
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
  
  // Services
  final UserService _userService = UserService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final ProductCacheService _productCacheService = ProductCacheService();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  
  // State variables
  UserModel? user;
  List<ProductModel> userProducts = [];
  bool isLoading = true;
  bool hasInternet = true;
  String? errorMessage;
  
  // Cache key for this user's products
  String get userProductsCacheKey => 'user_products_${widget.userId}';

  @override
  void initState() {
    super.initState();
    _initializeUserProfile();
  }

  /// Initialize user profile with offline-first approach
  Future<void> _initializeUserProfile() async {
    try {
      print('📱 UserProfileScreen: Initializing for user ${widget.userId}');
      
      // Check connectivity first
      hasInternet = await _connectivityService.checkConnectivity();
      print('🌐 Internet available: $hasInternet');
      
      // Load user data (offline-first)
      await _loadUserData();
      
      // Load user products (offline-first)
      await _loadUserProducts();
      
      // Trigger in-app messaging if online
      if (hasInternet) {
        _triggerInAppMessaging();
      }
      
    } catch (e) {
      print('❌ Error initializing user profile: $e');
      _setError('Error loading profile: $e');
    }
  }

  /// Load user data with offline-first strategy
  Future<void> _loadUserData() async {
    try {
      print('👤 Loading user data for: ${widget.userId}');
      
      // Use initial data if provided (from navigation)
      if (widget.initialUserData != null) {
        print('✅ Using provided initial user data');
        user = widget.initialUserData;
        setState(() {}); // Update UI immediately
        return;
      }
      
      // Try to get user from UserService (which handles offline caching)
      final userData = await _userService.getUserById(widget.userId);
      
      if (userData != null) {
        user = userData;
        print('✅ User data loaded: ${user!.displayName}');
      } else {
        throw Exception('User not found');
      }
      
      if (mounted) setState(() {});
      
    } catch (e) {
      print('❌ Error loading user data: $e');
      _setError('Could not load user information');
    }
  }

  /// Load user products with caching strategy
  Future<void> _loadUserProducts() async {
    try {
      print('📦 Loading products for user: ${widget.userId}');
      
      // First try to load from cache (instant)
      await _loadProductsFromCache();
      
      // Then try to refresh from network if online
      if (hasInternet) {
        await _refreshProductsFromNetwork();
      } else {
        print('📵 Offline mode: Using cached products only');
      }
      
    } catch (e) {
      print('❌ Error loading user products: $e');
      if (userProducts.isEmpty) {
        _setError('Could not load products');
      }
    } finally {
      isLoading = false;
      if (mounted) setState(() {});
    }
  }

  /// Load products from local cache
  Future<void> _loadProductsFromCache() async {
    try {
      // Try to get cached products for this specific user
      final cachedProducts = await _getCachedUserProducts();
      
      if (cachedProducts.isNotEmpty) {
        userProducts = cachedProducts;
        print('✅ Loaded ${userProducts.length} products from cache');
        
        if (mounted) setState(() {}); // Update UI immediately
      } else {
        print('ℹ️ No cached products found for user');
      }
    } catch (e) {
      print('⚠️ Error loading from cache: $e');
    }
  }

  /// Refresh products from network
  Future<void> _refreshProductsFromNetwork() async {
    try {
      print('🔄 Refreshing products from network...');
      
      final productMaps = await _firebaseDAO.getProductsByUserId(widget.userId)
          .timeout(const Duration(seconds: 10));
      
      final loadedProducts = productMaps
          .map((map) => ProductModel.fromMap(map, docId: map['id']))
          .toList();
      
      // Update products list
      userProducts = loadedProducts;
      
      // Cache the updated products
      await _cacheUserProducts(loadedProducts);
      
      print('✅ Refreshed ${userProducts.length} products from network');
      
      if (mounted) setState(() {});
      
    } catch (e) {
      print('⚠️ Error refreshing from network: $e');
      // Don't throw error here - we might have cached data
    }
  }

  /// Get cached products for this user
  Future<List<ProductModel>> _getCachedUserProducts() async {
    try {
      // Try to get from ProductCacheService first
      final allCachedProducts = await _productCacheService.loadAllProductsFromCache();
      
      if (allCachedProducts.isNotEmpty) {
        // Filter products by this user
        final userSpecificProducts = allCachedProducts
            .where((product) => product.sellerID == widget.userId)
            .toList();
        
        return userSpecificProducts;
      }
      
      return [];
    } catch (e) {
      print('Error getting cached user products: $e');
      return [];
    }
  }

  /// Cache user products
  Future<void> _cacheUserProducts(List<ProductModel> products) async {
    try {
      // We could implement user-specific caching here
      // For now, we'll rely on the general product cache
      await _productCacheService.saveAllProducts(products);
      print('💾 Cached ${products.length} products');
    } catch (e) {
      print('⚠️ Error caching products: $e');
    }
  }

  /// Trigger in-app messaging for reviews
  Future<void> _triggerInAppMessaging() async {
    try {
      if (user?.ratingAverage != null && user!.ratingAverage! >= 4.5) {
        fiam.triggerEvent('great_reviews');
      }
    } catch (e) {
      print('⚠️ Error triggering in-app messaging: $e');
    }
  }

  /// Set error state
  void _setError(String message) {
    errorMessage = message;
    isLoading = false;
    if (mounted) setState(() {});
  }

  /// Refresh all data (pull-to-refresh)
  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    await _initializeUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          user?.displayName ?? "User Profile",
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
    if (errorMessage != null && user == null) {
      return _buildErrorState();
    }
    
    // Loading state (only if we have no data)
    if (isLoading && user == null) {
      return const Center(child: CupertinoActivityIndicator());
    }
    
    // Main content with pull-to-refresh
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Offline indicator
            if (!hasInternet) _buildOfflineIndicator(),
            
            // User Profile Header
            _buildProfileHeader(),
            
            // User Stats
            _buildUserStats(),
            
            // Products Section
            _buildProductsSection(),
          ],
        ),
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
            "Offline Mode - Showing most recent data",
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
              errorMessage ?? "Unknown error",
              style: GoogleFonts.inter(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: _refreshData,
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    if (user == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // User Avatar with cached network image
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
                child: _buildProfileImage(),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // User Name
          Text(
            user!.displayName,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // User Email
          Text(
            user!.email,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: CupertinoColors.systemGrey,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),

          // User Bio
          if (user!.bio != null && user!.bio!.isNotEmpty)
            Text(
              user!.bio!,
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
              if (user!.major != null && user!.major!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreyBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user!.major!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                "• Joined ${_formatDate(user!.createdAt ?? DateTime.now())}",
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

  Widget _buildProfileImage() {
    if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: user!.photoURL!,
        cacheManager: ProductCacheService.productImageCacheManager,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppColors.primaryBlue.withOpacity(0.1),
          child: const Center(
            child: CupertinoActivityIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => _buildDefaultAvatar(large: true),
      );
    } else {
      return _buildDefaultAvatar(large: true);
    }
  }

  Widget _buildUserStats() {
    if (user == null) return const SizedBox.shrink();
    
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
          _buildStatItem(
            user!.ratingAverage?.toStringAsFixed(1) ?? "N/A", 
            "Rating"
          ),
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

  Widget _buildProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                "Products",
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (isLoading)
                const CupertinoActivityIndicator()
              else if (!hasInternet)
                const Icon(
                  CupertinoIcons.wifi_slash,
                  color: CupertinoColors.systemGrey,
                  size: 18,
                ),
            ],
          ),
        ),
        _buildProductsGrid(),
      ],
    );
  }

  Widget _buildProductsGrid() {
    if (userProducts.isEmpty && !isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Icon(
                CupertinoIcons.cube_box,
                size: 48,
                color: CupertinoColors.systemGrey,
              ),
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
            // Product Image with caching
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 120,
                width: double.infinity,
                color: CupertinoColors.systemGrey6,
                child: _buildProductImage(product),
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

  Widget _buildProductImage(ProductModel product) {
    if (product.imageUrls.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: product.imageUrls.first,
        cacheManager: ProductCacheService.productImageCacheManager,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CupertinoActivityIndicator(),
        ),
        errorWidget: (context, url, error) => Center(
          child: SvgPicture.asset(
            "assets/svgs/ImagePlaceHolder.svg",
            height: 40,
            width: 40,
          ),
        ),
      );
    } else {
      return Center(
        child: SvgPicture.asset(
          "assets/svgs/ImagePlaceHolder.svg",
          height: 40,
          width: 40,
        ),
      );
    }
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