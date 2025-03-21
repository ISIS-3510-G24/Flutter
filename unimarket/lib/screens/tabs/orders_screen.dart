import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/screens/payment/payment_screen.dart'; // Importa PaymentScreen
import 'package:unimarket/services/product_service.dart'; // Importa ProductService

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _selectedTab = 1; // Inicia en "Buying"
  List<Map<String, dynamic>> buyingProducts = [];
  List<Map<String, dynamic>> historyProducts = [];
  List<Map<String, dynamic>> sellingProducts = [];
  final ProductService _productService = ProductService(); // Instancia de ProductService

  @override
  void initState() {
    super.initState();
    _fetchBuyingOrders();
    _fetchHistoryOrders();
    _fetchSellingOrders();
  }

  Future<void> _fetchBuyingOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User is not authenticated");
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('buyerID', isEqualTo: user.uid)
          .where('status', whereIn: ['Delivered', 'Purchased', 'Unpaid'])
          .get();

      final List<Map<String, dynamic>> orders = await Future.wait(snapshot.docs.map((doc) async {
        final product = await _productService.getProductById(doc['productID']);
        return {
          "orderId": doc.id,
          "productId": doc['productID'],
          "name": product != null ? product.title : "Product ID: ${doc['productID']}",
          "details": "Order Date: ${doc['orderDate'].toDate()}",
          "status": doc['status'],
          "action": doc['status'] == "Delivered" ? "Help" : doc['status'] == "Unpaid" ? "Complete" : "",
          "image": product != null && product.imageUrls.isNotEmpty ? product.imageUrls[0] : "assets/svgs/ImagePlaceHolder.svg",
          "price": _formatPrice(doc['price']),
        };
      }).toList());

      setState(() {
        buyingProducts = orders;
      });
    } catch (e) {
      print("Error fetching orders: $e");
    }
  }

  Future<void> _fetchHistoryOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User is not authenticated");
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('buyerID', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Completed')
          .get();

      final List<Map<String, dynamic>> orders = await Future.wait(snapshot.docs.map((doc) async {
        final product = await _productService.getProductById(doc['productID']);
        return {
          "orderId": doc.id,
          "productId": doc['productID'],
          "name": product != null ? product.title : "Product ID: ${doc['productID']}",
          "details": "Order Date: ${doc['orderDate'].toDate()}",
          "status": doc['status'],
          "action": "Help",
          "image": product != null && product.imageUrls.isNotEmpty ? product.imageUrls[0] : "assets/svgs/ImagePlaceHolder.svg",
          "price": _formatPrice(doc['price']),
        };
      }).toList());

      setState(() {
        historyProducts = orders;
      });
    } catch (e) {
      print("Error fetching history orders: $e");
    }
  }

  Future<void> _fetchSellingOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User is not authenticated");
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('sellerID', isEqualTo: user.uid)
          .get();

      final List<Map<String, dynamic>> orders = await Future.wait(snapshot.docs.map((doc) async {
        final product = await _productService.getProductById(doc['productID']);
        return {
          "orderId": doc.id,
          "productId": doc['productID'],
          "name": product != null ? product.title : "Product ID: ${doc['productID']}",
          "details": "Order Date: ${doc['orderDate'].toDate()}",
          "status": doc['status'],
          "action": "Modify",
          "image": product != null && product.imageUrls.isNotEmpty ? product.imageUrls[0] : "assets/svgs/ImagePlaceHolder.svg",
          "price": _formatPrice(doc['price']),
        };
      }).toList());

      setState(() {
        sellingProducts = orders;
      });
    } catch (e) {
      print("Error fetching selling orders: $e");
    }
  }

  String _formatPrice(dynamic price) {
    int wholePart = price.toInt();
    String priceString = wholePart.toString();
    String result = '';

    if (priceString.length > 6) {
      result = priceString[0] + "'";
      String remainingDigits = priceString.substring(1);
      for (int i = 0; i < remainingDigits.length; i++) {
        result += remainingDigits[i];
        int positionFromRight = remainingDigits.length - 1 - i;
        if (positionFromRight % 3 == 0 && i < remainingDigits.length - 1) {
          result += '.';
        }
      }
    } else {
      for (int i = 0; i < priceString.length; i++) {
        result += priceString[i];
        int positionFromRight = priceString.length - 1 - i;
        if (positionFromRight % 3 == 0 && i < priceString.length - 1) {
          result += '.';
        }
      }
    }

    return "$result \$";
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
        middle: Text(
          "Orders",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(CupertinoIcons.search, color: AppColors.primaryBlue),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildTabSelector(),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _getCurrentProducts().length,
                separatorBuilder: (context, index) =>
                    Container(height: 1, color: AppColors.lightGreyBackground),
                itemBuilder: (context, index) {
                  final product = _getCurrentProducts()[index];
                  return _buildProductItem(product);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.transparentGrey, // Fondo más claro
          borderRadius: BorderRadius.circular(30), // Bordes súper redondeados
        ),
        padding: const EdgeInsets.all(8), // Espaciado interno para suavizar bordes
        child: CupertinoSegmentedControl<int>(
          groupValue: _selectedTab,
          onValueChanged: (int newIndex) {
            setState(() {
              _selectedTab = newIndex;
            });
          },
          children: {
            0: _buildTabItem("History", 0),
            1: _buildTabItem("Buying", 1),
            2: _buildTabItem("Selling", 2),
          },
          selectedColor: AppColors.primaryBlue, // Azul oficial
          borderColor: CupertinoColors.transparent, // Sin bordes visibles
          unselectedColor: CupertinoColors.transparent, // Sin color de fondo,
          pressedColor: CupertinoColors.systemGrey4.withOpacity(0.2),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final bool isSelected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? CupertinoColors.white : CupertinoColors.black.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                product["image"]!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return SvgPicture.asset(
                    "assets/svgs/ImagePlaceHolder.svg",
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  );
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
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => PaymentScreen(
                        productId: product["productId"],
                        orderId: product["orderId"],
                      ),
                    ),
                  );
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
}