import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/models/product_model.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ProductService _productService = ProductService();
  bool _dataLoaded = false;
  bool _timeElapsed = false;
  late Connectivity _connectivity;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Programar la transición mínima de 2 segundos
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _timeElapsed = true;
      });
      _navigateIfReady();
    });

    // Iniciar precarga de datos
    _preloadProductData();
  }

  void _navigateIfReady() {
    if (_timeElapsed && _dataLoaded) {
      Navigator.of(context).pushReplacementNamed('/intro');
    }
  }

  Future<void> _preloadProductData() async {
    try {
      // Verificar conectividad primero (manejo seguro para evitar excepciones)
      bool isConnected = false;
      try {
        final results = await _connectivity.checkConnectivity();
        isConnected = results.isNotEmpty && results.first != ConnectivityResult.none;
      } catch (e) {
        print("Error checking connectivity: $e");
        // Si falla la comprobación, asumimos que puede haber conexión
        isConnected = true;
      }

      // Intentar cargar desde caché primero
      await _loadProductsFromCache();
      
      // Si hay conexión, cargar productos frescos
      if (isConnected) {
        try {
          // Cargar productos en paralelo para mayor velocidad
          final allProductsFuture = _productService.fetchAllProducts();
          final filteredProductsFuture = _productService.fetchProductsByMajor();
          
          final results = await Future.wait([
            allProductsFuture,
            filteredProductsFuture
          ]);
          
          List<ProductModel> allProducts = results[0];
          List<ProductModel> filteredProducts = results[1];
          
          // Guardar en caché
          await _saveProductsToCache(allProducts, filteredProducts);
        } catch (e) {
          print("Error preloading products from network: $e");
          // Aunque falle, ya tenemos datos de caché, así que podemos continuar
        }
      }
    } catch (e) {
      print("Error in preload process: $e");
    } finally {
      // Marcamos como cargado sin importar el resultado
      setState(() {
        _dataLoaded = true;
      });
      _navigateIfReady();
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

  // Load products from local cache (solo verificamos que existan)
  Future<void> _loadProductsFromCache() async {
    try {
      final allProductsFile = await _allProductsFile;
      final filteredProductsFile = await _filteredProductsFile;
      
      if (await allProductsFile.exists() && await filteredProductsFile.exists()) {
        print("Cache files verified successfully");
      }
    } catch (e) {
      print("Error verifying cache: $e");
    }
  }

  // Save products to local cache
  Future<void> _saveProductsToCache(List<ProductModel> allProducts, List<ProductModel> filteredProducts) async {
    try {
      final allProductsFile = await _allProductsFile;
      final filteredProductsFile = await _filteredProductsFile;
      
      // Guardar todos los productos en cache sin limitar a 20
      await allProductsFile.writeAsString(jsonEncode(
        allProducts.map((product) => product.toJson()).toList()
      ));
      
      await filteredProductsFile.writeAsString(jsonEncode(
        filteredProducts.map((product) => product.toJson()).toList()
      ));
      
      print("Products preloaded and saved to cache successfully");
    } catch (e) {
      print("Error saving products to cache: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF93D2FF), Color(0xFFBCE9FF)],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _controller.value * 2 * 3.1416,
                      child: child,
                    );
                  },
                  child: SvgPicture.asset(
                    'assets/svgs/LogoArrows.svg',
                    width: 350,
                    height: 350,
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/svgs/LogoCircle.svg',
                      width: 210,
                      height: 210,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}