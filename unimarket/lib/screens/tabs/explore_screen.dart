import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:isolate';
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

class ExploreScreenState extends State<ExploreScreen> with WidgetsBindingObserver {
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
  Isolate? _connectivityIsolate;
  ReceivePort? _receivePort;
  Timer? _connectivityCheckTimer;
  bool _hasInternetAccess = true;
  bool _isCheckingConnectivity = false;





@override
void initState() {
  super.initState();
  
  // Registrar el observer
  WidgetsBinding.instance.addObserver(this);
  
  // Iniciar asumiendo que no hay conexión hasta confirmar lo contrario
  setState(() {
    _hasInternetAccess = false;
    _isCheckingConnectivity = true;
  });
  
  // Cargar datos de caché inmediatamente mientras verificamos la conectividad
  _loadFilteredProductsFromCache();
  
  // Verificar conectividad y cargar datos si hay internet
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _performSingleConnectivityCheck();
    
    // Configurar listener para cambios de conectividad
    _setupConnectivityListener();
    
    // Solo cargar todos los productos si hay internet confirmado
    if (_hasInternetAccess) {
      _loadAllProducts();
    }
  });
}

@override
void dispose() {
  // Quitar el observer
  WidgetsBinding.instance.removeObserver(this);
  
  // Limpieza simple
  _connectivityCheckTimer?.cancel();
  _connectivitySubscription?.cancel();
  _isDisposed = true;
  super.dispose();
}
  // Método simplificado para verificar conectividad real (una sola vez)
Future<void> _performSingleConnectivityCheck() async {
  if (_isDisposed) return;
  
  setState(() {
    _isCheckingConnectivity = true;
  });
  
  try {
    // Primero verificar nivel de interfaz
    final results = await _connectivity.checkConnectivity();
    bool isConnected = results.isNotEmpty && results.first != ConnectivityResult.none;
    
    // Si ni siquiera hay interfaz conectada, definitivamente no hay internet
    if (!isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _hasInternetAccess = false;
          _isCheckingConnectivity = false;
        });
      }
      return;
    }
    
    // Si hay interfaz, actualizar ese estado
    if (mounted) {
      setState(() {
        _isConnected = true;
      });
    }
    
    // Verificar internet real con un socket seguro
    bool hasRealInternet = false;
    try {
      final socket = await Socket.connect('8.8.8.8', 53)
          .timeout(Duration(seconds: 3));
      socket.destroy();
      hasRealInternet = true;
    } catch (e) {
      print("No se pudo conectar al socket: $e");
      hasRealInternet = false;
    }
    
    if (mounted) {
      print("Conectividad real: $hasRealInternet");
      setState(() {
        _hasInternetAccess = hasRealInternet;
        _isCheckingConnectivity = false;
      });
      
      // Si hay internet real, cargar/actualizar datos
      if (hasRealInternet && !_isLoadingFiltered) {
        _refreshFilteredProducts();
      }
    }
  } catch (e) {
    print("Error al verificar conectividad: $e");
    if (mounted) {
      setState(() {
        _hasInternetAccess = false;
        _isCheckingConnectivity = false;
      });
    }
  }
}
  
void _handleRetryPressed() async {
  // Realizar verificación completa
  await _performSingleConnectivityCheck();
  
  // Si hay internet, refrescar datos
  if (_hasInternetAccess) {
    _onRefresh();
  }
}

void _setupConnectivityListener() {
  try {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Solo realizar verificación completa cuando detectamos un cambio
      if (!_isCheckingConnectivity) {
        _performSingleConnectivityCheck();
      }
    });
  } catch (e) {
    print("Error configurando listener de conectividad: $e");
  }
}


static void _connectivityCheckIsolate(List<dynamic> args) async {
  final SendPort sendPort = args[0];
  bool hasAccess = false;
  
  try {
    // Intenta conectarse a un servicio confiable (DNS de Google)
    final socket = await Socket.connect('8.8.8.8', 53)
        .timeout(Duration(seconds: 3));
    socket.destroy();
    hasAccess = true;
  } catch (e) {
    hasAccess = false;
  }
  
  // Envía el resultado al hilo principal
  sendPort.send(hasAccess);
}
// Iniciar el sistema de verificación con isolate
Future<void> _startInternetCheckWithIsolate() async {
  if (_isDisposed) return;
  
  // Primera verificación inmediata
  await _checkInternetAccessWithIsolate();
  
  // Cancelar cualquier timer existente
  _connectivityCheckTimer?.cancel();
  
  // Configurar verificación periódica pero solo si no hay banner mostrándose
  _connectivityCheckTimer = Timer.periodic(Duration(seconds: 15), (timer) async {
    // Solo verificar periódicamente si está en primer plano y montado
    if (!_isDisposed && mounted) {
      // Si hay conexión, verificamos periódicamente de forma discreta
      // Si no hay conexión, verificamos solo cuando el usuario lo solicite explícitamente
      if (_hasInternetAccess) {
        await _checkInternetAccessWithIsolate();
      }
    }
  });
}

// Método para verificar conectividad real con isolate
// Método para verificar conectividad real con isolate
Future<void> _checkInternetAccessWithIsolate() async {
  if (_isDisposed) return;
  
  // Solo marcar como verificando si no estamos ya verificando
  if (mounted && !_isCheckingConnectivity) {
    setState(() {
      _isCheckingConnectivity = true;
    });
  }
  
  _terminateConnectivityIsolate();
  _receivePort = ReceivePort();
  bool previousStatus = _hasInternetAccess;
  
  try {
    // Verificar primero la conexión a nivel de interfaz
    final results = await _connectivity.checkConnectivity();
    ConnectivityResult result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    bool interfaceConnected = result != ConnectivityResult.none;
    
    // Si no hay interfaz conectada, no hay necesidad de verificar internet
    if (!interfaceConnected) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _hasInternetAccess = false;
          _isCheckingConnectivity = false;
        });
      }
      return;
    }
    
    // Actualizar estado de la interfaz
    if (mounted) {
      setState(() {
        _isConnected = interfaceConnected;
      });
    }
    
    // Solo verificar internet real si hay interfaz conectada
    if (interfaceConnected) {
      _connectivityIsolate = await Isolate.spawn(
        _connectivityCheckIsolate,
        [_receivePort!.sendPort],
      );
      
      final result = await _receivePort!.first.timeout(
        Duration(seconds: 5),
        onTimeout: () => false,
      );
      
      bool newStatus = result is bool ? result : false;
      
      // Importante: Siempre actualizar el estado cuando terminamos de verificar
      if (mounted) {
        setState(() {
          _hasInternetAccess = newStatus;
          _isCheckingConnectivity = false;
        });
        
        print("Resultado verificación internet: $newStatus (cambiado: ${newStatus != previousStatus})");
        
        // Solo refrescar si la conectividad regresó
        if (newStatus && !previousStatus && !_isLoadingFiltered) {
          _refreshFilteredProducts();
          _loadAllProducts(); // También actualizar todos los productos
        }
      }
    }
  } catch (e) {
    print("Error en verificación: $e");
    if (mounted) {
      setState(() {
        _hasInternetAccess = false;
        _isCheckingConnectivity = false;
      });
    }
  } finally {
    _terminateConnectivityIsolate();
  }
}

// Método para limpiar el isolate
void _terminateConnectivityIsolate() {
  _connectivityIsolate?.kill(priority: Isolate.immediate);
  _connectivityIsolate = null;
  _receivePort?.close();
  _receivePort = null;
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
  
    // Si la conexión se perdió a nivel de interfaz, actualizar inmediatamente
    if (!isConnected && mounted) {
      setState(() {
        _hasInternetAccess = false;
        _isCheckingConnectivity = false;
      });
    }
    // Si la conexión se restaura a nivel de interfaz, verificar internet real
    // Pero solo si no estamos ya verificando
    else if (isConnected && !_isCheckingConnectivity) {
      _checkInternetAccessWithIsolate();
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
void didChangeAppLifecycleState(AppLifecycleState state) {
  // Solo realizar verificación cuando la app vuelve a primer plano
  if (state == AppLifecycleState.resumed) {
    _performSingleConnectivityCheck();
  }
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  
  // Solo realizar una verificación completa si no estamos ya verificando
  if (!_isCheckingConnectivity) {
    _performSingleConnectivityCheck();
  }
}

@override
Widget build(BuildContext context) {
  // Definir correctamente cuándo estamos offline
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
              // Banner de conexión - mostrar si estamos offline o verificando
              if (isOffline || _isCheckingConnectivity)
                Container(
                  // resto del código del banner...
                  width: double.infinity,
                  color: CupertinoColors.systemYellow.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
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
                              : !_isConnected 
                                ? "No network connection. Showing recent products."
                                : "No internet connection. Showing recent products.",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ),
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