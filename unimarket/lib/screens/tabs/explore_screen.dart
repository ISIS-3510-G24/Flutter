import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:unimarket/screens/product/product_upload.dart';
import 'package:unimarket/widgets/buttons/floating_action_button_factory.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';
import 'package:unimarket/screens/search/search_screen.dart';
import 'package:unimarket/services/product_cache_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  ExploreScreenState createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> {
  final ProductService _productService = ProductService();
  final ProductCacheService _cacheService = ProductCacheService();
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoadingFiltered = false;  // Carga separada para productos personalizados
  bool _isLoadingAll = true;         // Carga separada para todos los productos
  bool _isConnected = true;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isDisposed = false;


  @override
void initState() {
  super.initState();
  
  // Para evitar MissingPluginException, inicializar después del primer frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkConnectivity();
    _setupConnectivityListener();
    
    // Forzar la carga de All Products después de un breve delay
    // para dar tiempo a la UI de renderizarse primero
    Future.delayed(Duration(milliseconds: 500), () {
      _loadAllProducts();
    });
  });
  
  // Primero cargar productos personalizados desde caché (alta prioridad)
  _loadFilteredProductsFromCache();
}
@override
void dispose() {
  _isDisposed = true;
  super.dispose();
}
  
  // Método seguro para configurar el listener de conectividad
  void _setupConnectivityListener() {
    try {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
        // Usa el primer resultado de la lista, o NONE si la lista está vacía
        ConnectivityResult result = results.isNotEmpty ? results.first : ConnectivityResult.none;
        _handleConnectivityChange(result);
      });
    } catch (e) {
      print("Error setting up connectivity listener: $e");
    }
  }

  // Método seguro para verificar conectividad
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      // Usa el primer resultado de la lista, o NONE si la lista está vacía
      ConnectivityResult result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _handleConnectivityChange(result);
    } catch (e) {
      print("Error checking connectivity: $e");
      // Asumir conectado por defecto para intentar cargar datos
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
      }
    }
  }

  // Handle connectivity changes
  void _handleConnectivityChange(ConnectivityResult result) {
    bool isConnected = result != ConnectivityResult.none;
    
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });
    
      // Si la conexión se restaura, intentar actualizar productos personalizados primero
      if (isConnected && !_isLoadingFiltered) {
        _refreshFilteredProducts();
      }
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
      if (cachedProducts.isEmpty && _isConnected) {
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
    if (_isLoadingFiltered || !_isConnected) return;
    
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
  
 // Corregir la verificación de conectividad para que no bloquee la carga
// Método mejorado para cargar todos los productos
Future<void> _loadAllProducts() async {

  if (_isDisposed) return;
  // No verificar conectividad ni si ya está cargando
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
  
  // No verificar conectividad, siempre intentar refrescar
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
  
  
  // Improved image widget that checks the local cache first
 // Reemplaza el método _buildProductImage con esta versión corregida
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
// Añade este método para cargar las imágenes desde la red
Widget _buildNetworkImage(ProductModel product) {
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
                print("Error cargando imagen: $error");
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
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Explore",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Network status indicator
            if (!_isConnected)
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
                // Offline banner
                if (!_isConnected)
                  Container(
                    width: double.infinity,
                    color: CupertinoColors.systemYellow.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 16,
                          color: CupertinoColors.systemYellow,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "You are offline. Viewing cached products.",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
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
                          onPressed: _onRefresh,
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