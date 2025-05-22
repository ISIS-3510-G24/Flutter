import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Añadido para usar Badge
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unimarket/screens/product/product_upload_screen.dart';
import 'package:unimarket/screens/product/queued_products_screen.dart';
import 'package:unimarket/widgets/buttons/floating_action_button_factory.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';
import 'package:unimarket/screens/search/search_screen.dart';
import 'package:unimarket/services/product_cache_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/screens/product/queued_product_indicator.dart';
import 'package:unimarket/services/screen_metrics_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  ExploreScreenState createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> with WidgetsBindingObserver {
  final ProductService _productService = ProductService();
  final ProductCacheService _cacheService = ProductCacheService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final ScreenMetricsService _metricsService = ScreenMetricsService();
  
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoadingFiltered = false;
  bool _isLoadingAll = true;
  bool _isDisposed = false;
  bool _hasInternetAccess = true;
  bool _isCheckingConnectivity = false;
  bool _usedCachedAll = false; // Track if we're showing cached all products
  int _queuedProductsCount = 0; // Añadido: contador para la cola
  
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _checkingSubscription;
  StreamSubscription? _queueSubscription; // Añadido: suscripción a la cola

 @override
  void initState() {
    super.initState();
    
    // Registrar métricas
    _metricsService.recordScreenEntry('explore_metrics');
    
    // Register observer
    WidgetsBinding.instance.addObserver(this);
    
    // Get initial states
    _hasInternetAccess = _connectivityService.hasInternetAccess;
    _isCheckingConnectivity = _connectivityService.isChecking;
    
    // Subscribe to connectivity changes
    _connectivitySubscription = _connectivityService.connectivityStream.listen((hasInternet) {
      if (mounted) {
        setState(() {
          _hasInternetAccess = hasInternet;
        });
        
        // If connectivity returns, load data
        if (hasInternet) {
          _refreshFilteredProducts();
          _loadAllProducts();
        }
      }
    });
    
    // Subscribe to checking state changes
    _checkingSubscription = _connectivityService.checkingStream.listen((isChecking) {
      if (mounted) {
        // Only update checking state if there's no internet
        // This prevents the checking banner from briefly appearing when there's good connection
        if (!_hasInternetAccess || isChecking == false) {
          setState(() {
            _isCheckingConnectivity = isChecking;
          });
        }
      }
    });
    
    // Suscribirse a los cambios en la cola de productos
    _queueSubscription = _productService.queuedProductsStream.listen((queuedProducts) {
      if (mounted) {
        setState(() {
          _queuedProductsCount = queuedProducts.length;
        });
      }
    });
    
    // Load data from cache immediately
    _loadFilteredProductsFromCache();
    _loadAllProductsFromCache();
    
    // Check connectivity and load data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Only check connectivity if we don't have internet
      if (!_hasInternetAccess) {
        _connectivityService.checkConnectivity();
      } else {
        // Load products from network if we have internet
        _loadAllProducts();
        _refreshFilteredProducts();
      }
    });
  }
  
  @override
  void dispose() {
    // Registrar métricas
    _metricsService.recordScreenExit('explore_metrics');
    
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel subscriptions
    _connectivitySubscription?.cancel();
    _checkingSubscription?.cancel();
    _queueSubscription?.cancel(); // Cancelar suscripción a la cola
    _isDisposed = true;
    super.dispose();
  }
  
  void _handleRetryPressed() async {
    // Force a connectivity check
    bool hasInternet = await _connectivityService.checkConnectivity();
    
    // If there's internet, refresh data
    if (hasInternet) {
      _onRefresh();
    }
  }

  // Navegar a la pantalla de cola de productos
  void _navigateToQueuedProducts() {
    // Registrar métricas
    _metricsService.recordScreenExit('explore_metrics');
    
    // Navegar a la pantalla de productos en cola
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const QueuedProductsScreen(),
      ),
    ).then((_) {
      // Registrar re-entrada cuando vuelva
      _metricsService.recordScreenEntry('explore_metrics');
    });
  }

  // Load filtered products from cache (fast)
  Future<void> _loadFilteredProductsFromCache() async {
    if (_isLoadingFiltered) return;
    
    setState(() {
      _isLoadingFiltered = true;
    });
    
    try {
      // Load filtered products from cache
      final cachedProducts = await _cacheService.loadFilteredProducts();
      
      if (mounted) {
        setState(() {
          _filteredProducts = cachedProducts;
          _isLoadingFiltered = false;
        });
      }
      
      // If there are no products in cache or they're empty, try to load from network
      if (cachedProducts.isEmpty && _hasInternetAccess) {
        _refreshFilteredProducts();
      }
    } catch (e) {
      print("Error loading filtered products from cache: $e");
      if (mounted) {
        setState(() {
          _isLoadingFiltered = false;
        });
      }
    }
  }
  
  // NEW: Load all products from LRU cache
  Future<void> _loadAllProductsFromCache() async {
    if (_isDisposed) return;
    
    setState(() {
      _isLoadingAll = true;
    });
    
    try {
      final cachedProducts = await _cacheService.loadAllProductsFromCache();
      
      if (mounted) {
        setState(() {
          if (cachedProducts.isNotEmpty) {
            _allProducts = cachedProducts;
            _usedCachedAll = true;
          }
          _isLoadingAll = false;
        });
      }
      
      // If there's internet, we'll still fetch fresh data to update the cache
      if (_hasInternetAccess) {
        // We'll leave _isLoadingAll = false since we're showing cached data
        // The refresh will happen in the background
      }
    } catch (e) {
      print("Error loading all products from cache: $e");
      if (mounted) {
        setState(() {
          _isLoadingAll = false;
        });
      }
    }
  }
  
  // Update filtered products from network
  Future<void> _refreshFilteredProducts() async {
    if (_isLoadingFiltered || !_hasInternetAccess) return;
    
    setState(() {
      _isLoadingFiltered = true;
    });
    
    try {
      // Load filtered products from network
      final filteredProducts = await _productService.fetchProductsByMajor();
      
      // Save to cache and precache images
      await _cacheService.saveFilteredProducts(filteredProducts);
      
      if (mounted) {
        setState(() {
          _filteredProducts = filteredProducts;
          _isLoadingFiltered = false;
        });
      }
    } catch (e) {
      print("Error refreshing filtered products: $e");
      if (mounted) {
        setState(() {
          _isLoadingFiltered = false;
        });
      }
    }
  }
  
  // Improved method to load all products
  Future<void> _loadAllProducts() async {   
    if (_isDisposed || !_hasInternetAccess) return;
    
    print("_loadAllProducts(): Starting to load all products");
    
    // If we're already showing cached data, don't show loading indicator again
    if (!_usedCachedAll && mounted) {
      setState(() {
        _isLoadingAll = true;
      });
    }
    
    try {
      // Use a Future.delayed to ensure there are no concurrency issues
      await Future.delayed(Duration.zero);
      
      // Load all products from network
      final allProducts = await _productService.fetchAllProducts();
      
      print("_loadAllProducts(): Successfully loaded ${allProducts.length} products");
      
      // Save to LRU cache
      await _cacheService.saveAllProducts(allProducts);
      
      if (mounted) {
        setState(() {
          _allProducts = allProducts;
          _isLoadingAll = false;
          _usedCachedAll = false; // We now have fresh data
        });
      }
    } catch (e) {
      print("_loadAllProducts(): Error loading products: $e");
      if (mounted) {
        setState(() {
          _isLoadingAll = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    print("_onRefresh(): Refreshing data");
    
    try {
      // Refresh filtered products
      _refreshFilteredProducts();
      
      // Refresh all products
      _loadAllProducts();
      
      // Wait a bit to show the refresh indicator
      await Future.delayed(Duration(milliseconds: 800));
    } catch (e) {
      print("_onRefresh(): Error refreshing: $e");
    }
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
  
  // Navigate to the SearchScreen when search icon is tapped
  void _navigateToSearch() {
    // Registrar métricas
    _metricsService.recordScreenExit('explore_metrics');
    
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const SearchScreen(),
      ),
    ).then((_) {
      // Registrar re-entrada cuando vuelva
      _metricsService.recordScreenEntry('explore_metrics');
    });
  }
  
  // UPDATED: Build product image with CachedNetworkImage
  Widget _buildProductImage(ProductModel product) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: product.imageUrls.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: product.imageUrls.first,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheManager: ProductCacheService.productImageCacheManager,
                placeholder: (context, url) => Center(
                  child: CupertinoActivityIndicator(),
                ),
                errorWidget: (context, url, error) {
                  print("Error loading image: $error");
                  return SvgPicture.asset(
                    "assets/svgs/ImagePlaceHolder.svg",
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  );
                },
              )
            : SvgPicture.asset(
                "assets/svgs/ImagePlaceHolder.svg",
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
      ),
    );
  }

  // Product card widget to avoid code duplication
  Widget _buildProductCard(ProductModel product) {
    return GestureDetector(
      onTap: () {
        // Registrar métricas
        _metricsService.recordScreenExit('explore_metrics');
        
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (ctx) => ProductDetailScreen(product: product),
          ),
        ).then((_) {
          // Registrar re-entrada cuando vuelva
          _metricsService.recordScreenEntry('explore_metrics');
        });
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey4,
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildProductImage(product),
            ),
            const SizedBox(height: 10),
            Text(
              product.title,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _formatPrice(product.price),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Registrar re-entrada cuando la app vuelve al primer plano
      _metricsService.recordScreenEntry('explore_metrics');
      
      // Check connectivity and clear old cache when the app is resumed
      _connectivityService.checkConnectivity();
      _cacheService.clearOldCache(); // New: clear old cached items periodically
    } else if (state == AppLifecycleState.paused) {
      // Registrar salida cuando la app va a segundo plano
      _metricsService.recordScreenExit('explore_metrics');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current connectivity state
    bool isOffline = !_hasInternetAccess;
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Explore",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Network status indicator - only show if we're offline
            if (isOffline && !_isCheckingConnectivity)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  CupertinoIcons.wifi_slash,
                  size: 18,
                  color: CupertinoColors.systemRed,
                ),
              ),
            
            // NUEVO: Botón para ver la cola de productos
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: _navigateToQueuedProducts,
                child: Stack(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 24,
                      color: AppColors.primaryBlue,
                    ),
                    if (_queuedProductsCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemRed,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            _queuedProductsCount > 9 ? '9+' : _queuedProductsCount.toString(),
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Ícono de búsqueda
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _navigateToSearch,
              child: const Icon(
                CupertinoIcons.search,
                size: 26,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Connection banner with improved logic
                if (isOffline || _isCheckingConnectivity)
                  Container(
                    width: double.infinity,
                    color: CupertinoColors.systemYellow.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        // Only show activity indicator if we're checking
                        _isCheckingConnectivity 
                            ? CupertinoActivityIndicator(radius: 8)
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
                                : "No internet connection. Showing recent products.",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                        // Only show Retry if we're NOT checking
                        if (!_isCheckingConnectivity)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            child: Text(
                              "Retry",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            onPressed: _handleRetryPressed,
                          ),
                      ],
                    ),
                  ),
                
                // NUEVO: Banner de Productos en Cola (visible solo cuando no hay banner de conexión)
                if (_queuedProductsCount > 0 && !isOffline && !_isCheckingConnectivity)
                  GestureDetector(
                    onTap: _navigateToQueuedProducts,
                    child: Container(
                      width: double.infinity,
                      color: AppColors.primaryBlue.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 16, 
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "$_queuedProductsCount ${_queuedProductsCount == 1 ? 'product' : 'products'} pending upload",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                            color: AppColors.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: _onRefresh,
                      ),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            // Filtered products section
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                "Perfect for you",
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _isLoadingFiltered
                                  ? Container(
                                      height: 200,
                                      alignment: Alignment.center,
                                      child: const CupertinoActivityIndicator(),
                                    )
                                  : _filteredProducts.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: Text(
                                              "No personalized products found",
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: CupertinoColors.systemGrey,
                                              ),
                                            ),
                                          ),
                                        )
                                      : GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            childAspectRatio: 0.9,
                                            crossAxisSpacing: 10,
                                            mainAxisSpacing: 10,
                                          ),
                                          itemCount: _filteredProducts.length,
                                          itemBuilder: (context, index) {
                                            final product = _filteredProducts[index];
                                            return _buildProductCard(product);
                                          },
                                        ),
                            ),
                            const SizedBox(height: 20),
                            // All products section
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: [
                                  Text(
                                    "All",
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  if (_usedCachedAll && !isOffline)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        "(Cached)",
                                        style: GoogleFonts.inter(fontSize: 12, color: CupertinoColors.systemGrey),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _isLoadingAll && !_usedCachedAll
                                  ? Container(
                                      height: 200,
                                      alignment: Alignment.center,
                                      child: const CupertinoActivityIndicator(),
                                    )
                                  : _allProducts.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: Text(
                                              "No products available",
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: CupertinoColors.systemGrey,
                                              ),
                                            ),
                                          ),
                                        )
                                      : GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            childAspectRatio: 0.9,
                                            crossAxisSpacing: 10,
                                            mainAxisSpacing: 10,
                                          ),
                                          itemCount: _allProducts.length,
                                          itemBuilder: (context, index) {
                                            final product = _allProducts[index];
                                            return _buildProductCard(product);
                                          },
                                        ),
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Add the FloatingActionButtonFactory at the bottom of the stack
          FloatingActionButtonFactory(
            buttonText: "Add Product",
            destinationScreen: const UploadProductScreen(),
          ),
        ],
      ),
    );
  }
}