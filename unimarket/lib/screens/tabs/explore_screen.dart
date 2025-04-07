import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:unimarket/screens/product/product_upload.dart';
import 'package:unimarket/widgets/buttons/floating_action_button_factory.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';
import 'package:unimarket/screens/search/search_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  ExploreScreenState createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen> {
  final ProductService _productService = ProductService();
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = true;
  bool _isConnected = true;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    
    // Para evitar MissingPluginException, inicializar después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivity();
      _setupConnectivityListener();
    });
    
    // Cargar productos inmediatamente
    _loadProductsFromCache().then((_) {
      if (mounted) {
        // Solo consultar la red si la caché está vacía
        if (_allProducts.isEmpty) {
          _loadProducts();
        } else {
          // La caché ya tiene datos, intentamos actualizar en segundo plano
          _refreshProductsInBackground();
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
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
    
      // If connection is restored, try to fetch fresh data in background
      if (isConnected && !_isLoading) {
        _refreshProductsInBackground();
      }
    }
  }

  // Actualizar productos en segundo plano sin mostrar indicador de carga
  Future<void> _refreshProductsInBackground() async {
    if (!_isConnected) return;
    
    try {
      List<ProductModel> allProducts = await _productService.fetchAllProducts();
      List<ProductModel> filteredProducts = await _productService.fetchProductsByMajor();
      
      if (mounted) {
        setState(() {
          _allProducts = allProducts;
          _filteredProducts = filteredProducts;
          _isConnected = true;
        });
      }
      
      // Guardar en caché
      _saveProductsToCache();
    } catch (e) {
      print("Error refreshing products in background: $e");
      // No cambiar el estado de conectividad ya que es una operación en segundo plano
    }
  }

  // Get the local storage directory path
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Path for cache files
  Future<File> get _allProductsFile async {
    final path = await _localPath;
    return File('$path/all_products_cache.json');
  }

  Future<File> get _filteredProductsFile async {
    final path = await _localPath;
    return File('$path/filtered_products_cache.json');
  }

  // Save products to local cache
  Future<void> _saveProductsToCache() async {
    try {
      final allProductsFile = await _allProductsFile;
      final filteredProductsFile = await _filteredProductsFile;
      
      // Guardar todos los productos sin limitar a 20
      await allProductsFile.writeAsString(jsonEncode(
        _allProducts.map((product) => product.toJson()).toList()
      ));
      
      await filteredProductsFile.writeAsString(jsonEncode(
        _filteredProducts.map((product) => product.toJson()).toList()
      ));
      
      print("Products saved to cache successfully");
    } catch (e) {
      print("Error saving products to cache: $e");
    }
  }

  // Load products from local cache
  Future<void> _loadProductsFromCache() async {
    try {
      final allProductsFile = await _allProductsFile;
      final filteredProductsFile = await _filteredProductsFile;
      
      if (await allProductsFile.exists() && await filteredProductsFile.exists()) {
        final allProductsStr = await allProductsFile.readAsString();
        final allProductsJson = jsonDecode(allProductsStr) as List;
        
        final filteredProductsStr = await filteredProductsFile.readAsString();
        final filteredProductsJson = jsonDecode(filteredProductsStr) as List;
        
        if (mounted) {
          setState(() {
            _allProducts = allProductsJson
                .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
                .toList();
                
            _filteredProducts = filteredProductsJson
                .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
                .toList();
                
            _isLoading = false;
          });
        }
        
        print("Products loaded from cache successfully");
        return;
      }
    } catch (e) {
      print("Error loading products from cache: $e");
    }
    
    // Si no hay caché o hay error, mantener la lista vacía
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    // No volver a cargar si ya está cargando
    if (_isLoading) return;
    
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      // Intentar cargar desde la red independientemente del estado de conectividad
      List<ProductModel> allProducts = await _productService.fetchAllProducts();
      List<ProductModel> filteredProducts = await _productService.fetchProductsByMajor();
      
      if (mounted) {
        setState(() {
          _allProducts = allProducts;
          _filteredProducts = filteredProducts;
          _isConnected = true; // Si llegamos aquí, confirmar que hay conexión
          _isLoading = false;
        });
      }
      
      // Save fetched products to cache
      _saveProductsToCache();
    } catch (e) {
      print("Error loading products from network: $e");
      
      // Marcar como desconectado si no podemos cargar datos
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
      }
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
  
  // Improved image widget that properly handles different image sources
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
                          onPressed: _loadProducts,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CupertinoActivityIndicator())
                      : _allProducts.isEmpty
                          ? Center(
                              child: Text(
                                "No products available",
                                style: GoogleFonts.inter(fontSize: 16),
                              ),
                            )
                          : CustomScrollView(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              slivers: [
                                CupertinoSliverRefreshControl(
                                  onRefresh: _loadProducts,
                                ),
                                SliverToBoxAdapter(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),
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
                                        child: _filteredProducts.isEmpty
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
                                        child: GridView.builder(
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