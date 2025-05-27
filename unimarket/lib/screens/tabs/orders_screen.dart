import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/screens/payment/payment_screen.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/models/order_model.dart';
import 'package:unimarket/services/cache_orders_service.dart';
import 'package:unimarket/services/connectivity_service.dart';
import 'package:unimarket/screens/orders/order_details_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedTab = 1; // Default tab is "Buying"
  List<Map<String, dynamic>> buyingProducts = [];
  List<Map<String, dynamic>> historyProducts = [];
  List<Map<String, dynamic>> sellingProducts = [];
  final ProductService _productService =  ProductService();

  final CacheOrdersService<String, Map<String, dynamic>> _ordersCache =
      CacheOrdersService(50, "orders_cache");
  final ConnectivityService _connectivityService = ConnectivityService();
  late StreamSubscription<bool> _connectivitySubscription;
  late StreamSubscription<bool> _checkingSubscription;

  bool _isConnected = true;
  bool _isCheckingConnectivity = false;

  Map<String, dynamic>? _orderStatistics;

  @override
  void initState() {
    super.initState();
    _initializeCache().then((_) {
      _setupConnectivityListener();
      _loadOrdersWithCache("buying", _fetchBuyingOrders);
      _loadOrdersWithCache("history", _fetchHistoryOrders).then((_) {
        _calculateOrderStatistics(historyProducts).then((stats) {
          setState(() {
            _orderStatistics = stats;
          });
        });
      });
      _loadOrdersWithCache("selling", _fetchSellingOrders);
      _checkAndShowPeakHourNotification();
    });
  }

  Future<void> _initializeCache() async {
    await _ordersCache.loadFromStorage();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen((bool isConnected) {
      setState(() {
        _isConnected = isConnected;
      });
    });

    _checkingSubscription = _connectivityService.checkingStream.listen((bool isChecking) {
      setState(() {
        _isCheckingConnectivity = isChecking;
      });
    });
  }

  void _handleRetryPressed() async {
    bool hasInternet = await _connectivityService.checkConnectivity();
    setState(() {
      _isConnected = hasInternet;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _checkingSubscription.cancel();
    super.dispose();
  }

  void _clearCache() async {
    await _ordersCache.clear();
    setState(() {
      buyingProducts = [];
      historyProducts = [];
      sellingProducts = [];
    });
  }

  void _checkAndShowPeakHourNotification() {
    print("Checking and showing peak hour notification...");
  }

  Future<void> _loadOrdersWithCache(
      String cacheKey, Future<List<Map<String, dynamic>>> Function() fetchFunction) async {
    final cachedOrders = <Map<String, dynamic>>[];
    for (var order in buyingProducts) {
      final cachedOrder = _ordersCache.get(order['orderId']);
      if (cachedOrder != null) {
        cachedOrders.add(cachedOrder);
      }
    }
    if (cachedOrders.isNotEmpty) {
      setState(() {
        if (cacheKey == "buying") buyingProducts = cachedOrders;
        if (cacheKey == "history") historyProducts = cachedOrders;
        if (cacheKey == "selling") sellingProducts = cachedOrders;
      });
      return;
    }
    final orders = await fetchFunction();
    for (var order in orders) {
      await _ordersCache.put(order['orderId'], order);
    }
    setState(() {
      if (cacheKey == "buying") buyingProducts = orders;
      if (cacheKey == "history") historyProducts = orders;
      if (cacheKey == "selling") sellingProducts = orders;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchBuyingOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('buyerID', isEqualTo: user.uid)
          .where('status', whereIn: ['Delivered', 'Purchased', 'Unpaid'])
          .get();

      return await Future.wait(snapshot.docs.map((doc) async {
        final product = await _productService.getProductById(doc['productID']);
        return {
          "orderId": doc.id,
          "productId": doc['productID'],
          "name": product?.title ?? "Product ID: ${doc['productID']}",
          "details": "Order Date: ${doc['orderDate'].toDate()}",
          "status": doc['status'],
          "action": doc['status'] == "Delivered" ? "Help" : doc['status'] == "Unpaid" ? "Complete" : "",
          "image": product?.imageUrls.isNotEmpty == true ? product!.imageUrls[0] : "assets/svgs/ImagePlaceHolder.svg",
          "price": _formatPrice(doc['price']),
        };
      }).toList());
    } catch (e) {
      print("Error fetching buying orders: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchHistoryOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User is not authenticated");
      return [];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('buyerID', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Purchased')
          .get();

      return await Future.wait(snapshot.docs.map((doc) async {
        final product = await _productService.getProductById(doc['productID']);
        return {
          "orderId": doc.id,
          "productId": doc['productID'],
          "name": product != null ? product.title : "Product ID: ${doc['productID']}",
          "details": "Order Date: ${doc['orderDate'].toDate()}",
          "status": doc['status'],
          "action": "Help",
          "image": product != null && product.imageUrls.isNotEmpty
              ? product.imageUrls[0]
              : "assets/svgs/ImagePlaceHolder.svg",
          "price": _formatPrice(doc['price']),
        };
      }).toList());
    } catch (e) {
      print("Error fetching history orders: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSellingOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User is not authenticated");
      return [];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('sellerID', isEqualTo: user.uid)
          .get();

      return await Future.wait(snapshot.docs.map((doc) async {
        final product = await _productService.getProductById(doc['productID']);
        return {
          "orderId": doc.id,
          "productId": doc['productID'],
          "name": product != null ? product.title : "Product ID: ${doc['productID']}",
          "details": "Order Date: ${doc['orderDate'].toDate()}",
          "status": doc['status'],
          "action": "Modify",
          "image": product != null && product.imageUrls.isNotEmpty
              ? product.imageUrls[0]
              : "assets/svgs/ImagePlaceHolder.svg",
          "price": _formatPrice(doc['price']),
        };
      }).toList());
    } catch (e) {
      print("Error fetching selling orders: $e");
      return [];
    }
  }

  String _formatPrice(dynamic price) {
    final priceString = price.toInt().toString();
    return "${priceString.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.')} \$";
  }

  List<Map<String, dynamic>> _getCurrentProducts() {
    switch (_selectedTab) {
      case 0:
        return historyProducts;
      case 1:
        return buyingProducts;
      case 2:
        return sellingProducts;
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          "Orders",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.trash, color: AppColors.primaryBlue),
          onPressed: _clearCache,
        ),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                if (!_isConnected || _isCheckingConnectivity)
                  Container(
                    width: double.infinity,
                    color: CupertinoColors.systemYellow.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        _isCheckingConnectivity
                            ? const CupertinoActivityIndicator(radius: 8)
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
                                : "You are offline. Some features may not work.",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                        if (!_isCheckingConnectivity)
                          CupertinoButton(
                            onPressed: _handleRetryPressed,
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            child: const Text(
                              "Retry",
                              style: TextStyle(fontSize: 12, color: AppColors.primaryBlue),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                _buildTabSelector(),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 60), // Espacio para la barra
                    itemCount: _getCurrentProducts().length,
                    itemBuilder: (context, index) {
                      final product = _getCurrentProducts()[index];
                      return _buildProductItem(product);
                    },
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildOrderStatisticsBar(), // Barra fija en la parte inferior
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.white, // Fondo blanco para que no se vea raro
          borderRadius: BorderRadius.circular(30), // Bordes redondeados
        ),
        padding: const EdgeInsets.all(8),
        child: CupertinoSegmentedControl<int>(
          groupValue: _selectedTab,
          onValueChanged: (int newIndex) {
            setState(() {
              _selectedTab = newIndex;
            });
          },
          children: const {
            0: Text(
              "History",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: AppColors.primaryBlue,
              ),
            ),
            1: Text(
              "Buying",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: AppColors.primaryBlue,
              ),
            ),
            2: Text(
              "Selling",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: AppColors.primaryBlue,
              ),
            ),
          },
          selectedColor: AppColors.primaryBlue, // Color del botón seleccionado
          borderColor: AppColors.primaryBlue, // Borde azul para que se vea como antes
          unselectedColor: CupertinoColors.white, // Fondo blanco para los botones no seleccionados
          pressedColor: CupertinoColors.systemGrey4.withOpacity(0.2), // Color al presionar
        ),
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        _ordersCache.put(product['orderId'], product);
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => OrderDetailsScreen(order: product),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FutureBuilder<File?>(
                future: _loadCachedImage(product["image"]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // microoptimization const
                    return const CupertinoActivityIndicator();
                  } else if (snapshot.hasError || snapshot.data == null) {
                    return SvgPicture.asset(
                      "assets/svgs/ImagePlaceHolder.svg",
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    );
                  } else {
                    return Image.file(
                      snapshot.data!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product["name"]!,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                  Text(
                    product["details"]!,
                    style: GoogleFonts.inter(fontSize: 14, color: CupertinoColors.systemGrey),
                  ),
                  if (product.containsKey("price"))
                    Text(
                      product["price"]!,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                    ),
                  if (product.containsKey("status"))
                    Text(
                      product["status"]!,
                      style: GoogleFonts.inter(fontSize: 14, color: CupertinoColors.systemGrey),
                    ),
                ],
              ),
            ),
            if (_selectedTab != 2) ...[
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryBlue,
                  ),
                  child: const Icon(
                    CupertinoIcons.chat_bubble,
                    color: CupertinoColors.white,
                    size: 20,
                  ),
                ),
                onPressed: () {},
              ),
            ],
            const SizedBox(width: 10),
            if (_selectedTab == 1 && product["status"] == "Unpaid")
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (!_isConnected) {
                    showCupertinoDialog(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text("Uh! Oh!"),
                        content: const Text("You can't make payments offline."),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text("OK"),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => PaymentScreen(
                          productId: product["productId"],
                          orderId: product["orderId"],
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  "Complete",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            if (product["status"] == "Purchased")
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await _generateAndCacheReceipt(product);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryBlue,
                  ),
                  child: const Icon(
                    CupertinoIcons.printer,
                    color: CupertinoColors.white,
                    size: 20,
                  ),
                ),
              ),
            if (_selectedTab == 2) ...[
              const SizedBox(width: 10),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.lightGreyBackground,
                  ),
                  child: const Icon(
                    CupertinoIcons.clear_circled,
                    color: CupertinoColors.systemGrey,
                    size: 20,
                  ),
                ),
                onPressed: () {},
              ),
            ]
          ],
        ),
      ),
    );
  }

  Future<File?> _loadCachedImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final file = await DefaultCacheManager().getSingleFile(imageUrl);
      return file.existsSync() ? file : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _generateAndCacheReceipt(Map<String, dynamic> product) async {
    try {
      // Verificar si el archivo ya está en el caché
      final cachedFile = await DefaultCacheManager().getFileFromCache('${product["orderId"]}_receipt.txt');
      if (cachedFile != null) {
        print("Receipt already cached: ${cachedFile.file.path}");
        await OpenFile.open(cachedFile.file.path);
        return;
      }

      // Generar el contenido del recibo
      final receiptContent = '''
Order Receipt
=============
Order ID: ${product["orderId"]}
Product Name: ${product["name"]}
Price: ${product["price"]}
Status: ${product["status"]}
Order Date: ${product["details"]}
''';

      // Crear un archivo temporal para el recibo
      final tempDir = await getTemporaryDirectory();
      final receiptFile = File('${tempDir.path}/${product["orderId"]}_receipt.txt');

      // Escribir el contenido en el archivo
      await receiptFile.writeAsString(receiptContent);

      // Guardar el archivo en el caché
      await DefaultCacheManager().putFile(
        receiptFile.path,
        receiptFile.readAsBytesSync(),
      );

      // Abrir el archivo generado
      await OpenFile.open(receiptFile.path);

      print("Receipt generated and cached: ${receiptFile.path}");
    } catch (e) {
      print("Error generating receipt: $e");
    }
  }

  Future<void> _saveToDownloads(File file) async {
    final downloadsDir = await getApplicationDocumentsDirectory(); // Cambiar a getDownloadsDirectory() si es compatible
    final newFile = File('${downloadsDir.path}/${file.path.split('/').last}');
    await file.copy(newFile.path);
    print("File saved to downloads: ${newFile.path}");
  }

  Widget _buildOrderStatistics() {
    if (_orderStatistics == null) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Order Statistics",
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 8),
          Text(
            "Total Spent: ${_orderStatistics!["totalSpent"].toStringAsFixed(2)} \$",
            style: GoogleFonts.inter(fontSize: 14, color: CupertinoColors.systemGrey),
          ),
          Text(
            "Completed Orders: ${_orderStatistics!["completedOrders"]}",
            style: GoogleFonts.inter(fontSize: 14, color: CupertinoColors.systemGrey),
          ),
          Text(
            "Unpaid Orders: ${_orderStatistics!["unpaidOrders"]}",
            style: GoogleFonts.inter(fontSize: 14, color: CupertinoColors.systemGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatisticsBar() {
    if (_orderStatistics == null) {
      return const SizedBox.shrink(); // No mostrar nada si las estadísticas no están listas
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Total Spent: ${_orderStatistics!["totalSpent"].toStringAsFixed(2)} \$",
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
          ),
          Text(
            "Completed: ${_orderStatistics!["completedOrders"]}",
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
          ),
          Text(
            "Unpaid: ${_orderStatistics!["unpaidOrders"]}",
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>> _calculateOrderStatistics(List<Map<String, dynamic>> orders) async {
  return compute(_processOrderStatistics, orders);
}

Map<String, dynamic> _processOrderStatistics(List<Map<String, dynamic>> orders) {
  double totalSpent = 0;
  int completedOrders = 0;
  int unpaidOrders = 0;

  for (var order in orders) {
    if (order["status"] == "Purchased") {
      totalSpent += double.tryParse(order["price"].replaceAll(" \$", "").replaceAll(".", "")) ?? 0;
      completedOrders++;
    } else if (order["status"] == "Unpaid") {
      unpaidOrders++;
    }
  }

  return {
    "totalSpent": totalSpent,
    "completedOrders": completedOrders,
    "unpaidOrders": unpaidOrders,
  };
}