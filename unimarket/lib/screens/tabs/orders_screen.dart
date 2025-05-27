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
  final ProductService _productService = ProductService();
  final PageController _pageController = PageController(initialPage: 1);

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
    _pageController.dispose();
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
          "name": product?.title ?? "Unnamed Product",
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
          "name": product != null ? product.title : "Unnamed Product",
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
          "name": product != null ? product.title : "Unnamed Product",
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return CupertinoColors.systemGreen;
      case 'purchased':
        return CupertinoColors.systemBlue;
      case 'unpaid':
        return CupertinoColors.systemOrange;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withOpacity(0.9),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
        middle: Text(
          "Orders",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.black,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.trash,
              color: CupertinoColors.systemRed,
              size: 18,
            ),
          ),
          onPressed: _clearCache,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Connectivity Banner
            if (!_isConnected || _isCheckingConnectivity)
              _buildConnectivityBanner(),
            
            // Tab Selector
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildTabSelector(),
            ),
            
            // Main Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedTab = index;
                  });
                },
                children: [
                  _buildOrdersList(historyProducts),
                  _buildOrdersList(buyingProducts),
                  _buildOrdersList(sellingProducts),
                ],
              ),
            ),
            
            // Statistics Bar
            _buildOrderStatisticsBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectivityBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CupertinoColors.systemYellow.withOpacity(0.1),
            CupertinoColors.systemOrange.withOpacity(0.1),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemYellow.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemYellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _isCheckingConnectivity
                ? const CupertinoActivityIndicator(radius: 8)
                : const Icon(
                    CupertinoIcons.wifi_slash,
                    size: 16,
                    color: CupertinoColors.systemYellow,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isCheckingConnectivity
                  ? "Checking connection..."
                  : "You're offline. Some features may not work.",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemYellow.darkColor,
              ),
            ),
          ),
          if (!_isCheckingConnectivity)
            CupertinoButton(
              onPressed: _handleRetryPressed,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minSize: 0,
              borderRadius: BorderRadius.circular(6),
              color: CupertinoColors.systemYellow.withOpacity(0.2),
              child: Text(
                "Retry",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemYellow.darkColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: CupertinoSegmentedControl<int>(
        groupValue: _selectedTab,
        onValueChanged: (int newIndex) {
          setState(() {
            _selectedTab = newIndex;
          });
          _pageController.animateToPage(
            newIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        children: {
          0: _buildTabItem("History", 0),
          1: _buildTabItem("Buying", 1),
          2: _buildTabItem("Selling", 2),
        },
        selectedColor: AppColors.primaryBlue,
        borderColor: CupertinoColors.transparent,
        unselectedColor: CupertinoColors.transparent,
        pressedColor: AppColors.primaryBlue.withOpacity(0.1),
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedTab == index;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? CupertinoColors.white : AppColors.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildEmptyState() {
    final tabNames = ["history", "buying orders", "selling orders"];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _selectedTab == 0 ? CupertinoIcons.clock : 
                _selectedTab == 1 ? CupertinoIcons.shopping_cart : 
                CupertinoIcons.tag,
                size: 40,
                color: CupertinoColors.systemGrey3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "No ${tabNames[_selectedTab]} yet",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your ${tabNames[_selectedTab]} will appear here when available.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: CupertinoColors.systemGrey2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 80,
                height: 80,
                color: CupertinoColors.systemGrey6,
                child: FutureBuilder<File?>(
                  future: _loadCachedImage(product["image"]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CupertinoActivityIndicator(radius: 12),
                      );
                    } else if (snapshot.hasError || snapshot.data == null) {
                      return SvgPicture.asset(
                        "assets/svgs/ImagePlaceHolder.svg",
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      );
                    } else {
                      return Image.file(
                        snapshot.data!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      );
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product["name"]!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product["details"]!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (product.containsKey("price"))
                        Text(
                          product["price"]!,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      const Spacer(),
                      if (product.containsKey("status"))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(product["status"]!).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product["status"]!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(product["status"]!),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Action Buttons
            Column(
              children: [
                if (_selectedTab != 2)
                  _buildActionButton(
                    icon: CupertinoIcons.chat_bubble_text,
                    color: AppColors.primaryBlue,
                    onPressed: () {},
                  ),
                
                if (_selectedTab != 2) const SizedBox(height: 8),
                
                if (_selectedTab == 1 && product["status"] == "Unpaid")
                  _buildActionButton(
                    icon: CupertinoIcons.creditcard,
                    color: CupertinoColors.systemGreen,
                    onPressed: () {
                      if (!_isConnected) {
                        _showOfflineAlert();
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
                  ),
                
                if (product["status"] == "Purchased")
                  _buildActionButton(
                    icon: CupertinoIcons.doc_text,
                    color: AppColors.primaryBlue,
                    onPressed: () async {
                      await _generateAndCacheReceipt(product);
                    },
                  ),
                
                if (_selectedTab == 2)
                  _buildActionButton(
                    icon: CupertinoIcons.ellipsis_circle,
                    color: CupertinoColors.systemGrey,
                    onPressed: () {},
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: color,
          size: 18,
        ),
      ),
    );
  }

  void _showOfflineAlert() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Connection Required"),
        content: const Text("You need an internet connection to make payments."),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
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
      final cachedFile = await DefaultCacheManager().getFileFromCache('${product["orderId"]}_receipt.txt');
      if (cachedFile != null) {
        print("Receipt already cached: ${cachedFile.file.path}");
        await OpenFile.open(cachedFile.file.path);
        return;
      }

      final receiptContent = '''
Order Receipt
=============
Order ID: ${product["orderId"]}
Product: ${product["name"]}
Price: ${product["price"]}
Status: ${product["status"]}
Order Date: ${product["details"]}
''';

      final tempDir = await getTemporaryDirectory();
      final receiptFile = File('${tempDir.path}/${product["orderId"]}_receipt.txt');

      await receiptFile.writeAsString(receiptContent);

      await DefaultCacheManager().putFile(
        receiptFile.path,
        receiptFile.readAsBytesSync(),
      );

      await OpenFile.open(receiptFile.path);

      print("Receipt generated and cached: ${receiptFile.path}");
    } catch (e) {
      print("Error generating receipt: $e");
    }
  }

  Widget _buildOrderStatisticsBar() {
    if (_orderStatistics == null) {
      return Container(
        height: 80,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: const Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              "Total Spent",
              "${_orderStatistics!["totalSpent"].toStringAsFixed(2)} \$",
              AppColors.primaryBlue,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: CupertinoColors.separator,
          ),
          Expanded(
            child: _buildStatItem(
              "Completed",
              "${_orderStatistics!["completedOrders"]}",
              CupertinoColors.systemGreen,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: CupertinoColors.separator,
          ),
          Expanded(
            child: _buildStatItem(
              "Unpaid",
              "${_orderStatistics!["unpaidOrders"]}",
              CupertinoColors.systemOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: CupertinoColors.systemGrey,
          ),
        ),
      ],
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