import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/product/product_upload.dart';
import 'package:unimarket/widgets/buttons/floating_action_button_factory.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';
import 'package:unimarket/screens/search/search_screen.dart';
import 'package:unimarket/services/product_cache_service.dart';
import 'package:unimarket/services/connectivity_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  ExploreScreenState createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> with WidgetsBindingObserver {
  final ProductService _productService = ProductService();
  final ProductCacheService _cacheService = ProductCacheService();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoadingFiltered = false;
  bool _isLoadingAll = true;
  bool _isDisposed = false;
  bool _hasInternetAccess = true;
  bool _isCheckingConnectivity = false;
  
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _checkingSubscription;

 @override
  void initState() {
    super.initState();
    
    // Registrar el observer
    WidgetsBinding.instance.addObserver(this);
    
    // Obtener estados iniciales
    _hasInternetAccess = _connectivityService.hasInternetAccess;
    _isCheckingConnectivity = _connectivityService.isChecking;
    
    // Suscribirse a cambios de conectividad
    _connectivitySubscription = _connectivityService.connectivityStream.listen((hasInternet) {
      if (mounted) {
        setState(() {
          _hasInternetAccess = hasInternet;
        });
        
        // Si la conectividad regresa, cargar datos
        if (hasInternet) {
          _refreshFilteredProducts();
          _loadAllProducts();
        }
      }
    });
    
    // Suscribirse a cambios en el estado de verificación
    _checkingSubscription = _connectivityService.checkingStream.listen((isChecking) {
      if (mounted) {
        // Solo actualizar el estado de verificación si no hay internet
        // Esto evita que aparezca el banner de verificación brevemente cuando hay buena conexión
        if (!_hasInternetAccess || isChecking == false) {
          setState(() {
            _isCheckingConnectivity = isChecking;
          });
        }
      }
    });
    
    // Cargar datos de caché inmediatamente
    _loadFilteredProductsFromCache();
    
    // Verificar conectividad y cargar datos
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Cargar productos de todas formas para mostrar algo
      _loadAllProducts();
      
      // Solo verificar conectividad si no tenemos internet
      if (!_hasInternetAccess) {
        _connectivityService.checkConnectivity();
      }
    });
  }
  
  @override
  void dispose() {
    // Quitar el observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancelar suscripciones
    _connectivitySubscription?.cancel();
    _checkingSubscription?.cancel();
    _isDisposed = true;
    super.dispose();
  }
  
  void _handleRetryPressed() async {
    // Forzar una verificación de conectividad
    bool hasInternet = await _connectivityService.checkConnectivity();
    
    // Si hay internet, refrescar datos
    if (hasInternet) {
      _onRefresh();
    }
  }

  // Cargar productos personalizados desde caché (rápido)
  Future<void> _loadFilteredProductsFromCache() async {
    if (_isLoadingFiltered) return;
    
    setState(() {
      _isLoadingFiltered = true;
    });
    
    try {
      // Cargar productos personalizados desde caché
      final cachedProducts = await _cacheService.loadFilteredProducts();
      
      if (mounted) {
        setState(() {
          _filteredProducts = cachedProducts;
          _isLoadingFiltered = false;
        });
      }
      
      // Si no hay productos en caché o están vacíos, intentar cargar desde la red
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
  
  // Actualizar productos personalizados desde la red
  Future<void> _refreshFilteredProducts() async {
    if (_isLoadingFiltered || !_hasInternetAccess) return;
    
    setState(() {
      _isLoadingFiltered = true;
    });
    
    try {
      // Cargar productos personalizados desde la red
      final filteredProducts = await _productService.fetchProductsByMajor();
      
      // Guardar en caché y precargar imágenes
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
  
  // Método mejorado para cargar todos los productos
  Future<void> _loadAllProducts() async {
    if (_isDisposed) return;
    
    print("_loadAllProducts(): Iniciando carga de todos los productos");
    
    if (!mounted || _isDisposed) return;

    setState(() {
      _isLoadingAll = true;
    });
    
    try {
      // Usar un Future.delayed para asegurar que no hay problemas de concurrencia
      await Future.delayed(Duration.zero);
      
      // Cargar todos los productos desde la red
      final allProducts = await _productService.fetchAllProducts();
      
      print("_loadAllProducts(): Cargados ${allProducts.length} productos exitosamente");
      
      if (mounted) {
        setState(() {
          _allProducts = allProducts;
          _isLoadingAll = false;
        });
      }
    } catch (e) {
      print("_loadAllProducts(): Error cargando productos: $e");
      if (mounted) {
        setState(() {
          _isLoadingAll = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    print("_onRefresh(): Refrescando datos");
    
    try {
      // Refrescar productos personalizados
      _refreshFilteredProducts();
      
      // Refrescar todos los productos
      _loadAllProducts();
      
      // Esperar un poco para mostrar el indicador de refresh
      await Future.delayed(Duration(milliseconds: 800));
    } catch (e) {
      print("_onRefresh(): Error al refrescar: $e");
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
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const SearchScreen(),
      ),
    );
  }
  
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
            ? Image.network(
                product.imageUrls.first,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  print("Error loading image: $error");
                  return SvgPicture.asset(
                    "assets/svgs/ImagePlaceHolder.svg",
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CupertinoActivityIndicator(),
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
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (ctx) => ProductDetailScreen(product: product),
          ),
        );
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
    // Solo verificar conectividad cuando la app vuelve a primer plano
    if (state == AppLifecycleState.resumed) {
      _connectivityService.checkConnectivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener estado de conectividad actual
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
            // Network status indicator - solo mostrar si estamos offline
            if (isOffline && !_isCheckingConnectivity)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  CupertinoIcons.wifi_slash,
                  size: 18,
                  color: CupertinoColors.systemRed,
                ),
              ),
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
                // Banner de conexión con lógica mejorada
                if (isOffline || _isCheckingConnectivity)
                  Container(
                    width: double.infinity,
                    color: CupertinoColors.systemYellow.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        // Mostrar indicador de actividad solo si estamos verificando
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
                        // Mostrar Retry solo si NO estamos verificando
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
                            // Sección de productos personalizados
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
                            // Sección de todos los productos
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                "All",
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _isLoadingAll
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