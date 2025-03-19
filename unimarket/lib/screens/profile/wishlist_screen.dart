import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';
import 'package:unimarket/services/user_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  _WishlistScreenState createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final UserService _userService = UserService();
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Productos que llegan desde la wishlist de Firestore.
  List<ProductModel> _wishlistProducts = [];

  /// Para mostrar indicador de carga
  bool _isLoading = true;

  /// Set con los IDs de productos que *ya no* están en la wishlist
  /// (o sea, que se eliminaron en Firestore al pulsar el corazón).
  /// Siguen en la lista visual, pero con el ícono outline.
  final Set<String> _removedProductIds = {};

  /// Set con los IDs de productos que ya han mostrado el diálogo
  final Set<String> _shownDialogProductIds = {};

  /// Variable para rastrear si el diálogo ya se ha mostrado durante la sesión actual
  bool _dialogShownThisSession = false;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
    _trackScreenView();
    _checkDialogShown();
  }

  // Registro de analítica
  void _trackScreenView() {
    analytics.setCurrentScreen(screenName: "WishlistScreen");
  }

  /// Verifica si el diálogo ya se ha mostrado durante la sesión actual
  Future<void> _checkDialogShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _dialogShownThisSession = prefs.getBool('dialogShownThisSession') ?? false;
      });
    } catch (e) {
      print('Error checking dialog shown status: $e');
    }
  }

  /// Marca el diálogo como mostrado
  Future<void> _setDialogShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dialogShownThisSession', true);
    } catch (e) {
      print('Error setting dialog shown status: $e');
    }
  }

  /// Restablece el estado del diálogo mostrado (solo para desarrollo)
  Future<void> _resetDialogShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dialogShownThisSession', false);
      setState(() {
        _dialogShownThisSession = false;
      });
    } catch (e) {
      print('Error resetting dialog shown status: $e');
    }
  }

  /// Carga la wishlist desde Firestore
  Future<void> _loadWishlist() async {
    setState(() => _isLoading = true);
    try {
      final products = await _userService.getWishlistProducts();
      setState(() {
        _wishlistProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading wishlist: $e");
      setState(() => _isLoading = false);
    }
  }

  /// Elimina un producto de la wishlist al hacer swipe (Dismissible)
  Future<void> _removeFromWishlistImmediate(String productId) async {
    final success = await _userService.removeFromWishlist(productId);
    if (success && mounted) {
      setState(() {
        // Lo quitamos de la lista completamente
        _wishlistProducts.removeWhere((p) => p.id == productId);
        // Y por si lo habíamos marcado como “removido”
        _removedProductIds.remove(productId);
        // También lo quitamos del set de diálogos mostrados
        _shownDialogProductIds.remove(productId);
      });
    }
  }

  /// Lógica para alternar el wishlist de un producto
  /// de inmediato en Firestore al pulsar el corazón.
  ///
  /// - Si actualmente NO está en _removedProductIds => Significa que está en la wishlist
  ///   => lo removemos de Firestore y lo pasamos a outline.
  /// - Si SÍ está en _removedProductIds => lo volvemos a agregar a Firestore y pasa a rojo.
  Future<void> _toggleWishlistStatus(ProductModel product) async {
    if (product.id == null) return; 
    final productId = product.id!;

    final isRemoved = _removedProductIds.contains(productId);

    if (isRemoved) {
      // => el usuario lo “re-agrega” a la wishlist
      final added = await _userService.addToWishlist(productId);
      if (added && mounted) {
        setState(() {
          // Ya está en Firestore, por lo tanto lo quitamos del set de removidos
          _removedProductIds.remove(productId);
        });
      }
    } else {
      // => el usuario lo “desmarca” => removeFromWishlist
      final removed = await _userService.removeFromWishlist(productId);
      if (removed && mounted) {
        setState(() {
          // Marcamos este producto como “fuera” de la wishlist
          _removedProductIds.add(productId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "My Wishlist",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _resetDialogShown, // Botón para restablecer el estado del diálogo
          child: Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('Product').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final products = snapshot.data!.docs;
            List<String> notAvailableProducts = [];

            for (var product in products) {
              final productId = product.id;
              final productStatus = product['status'];

              if (_wishlistProducts.any((p) => p.id == productId) && productStatus == "Not available" && !_shownDialogProductIds.contains(productId)) {
                _shownDialogProductIds.add(productId);
                notAvailableProducts.add(productId);
              }
            }

            if (notAvailableProducts.isNotEmpty && !_dialogShownThisSession) {
              _dialogShownThisSession = true;
              _setDialogShown();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: Text('Products not available'),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: notAvailableProducts.map((productId) => Text('The product with ID $productId is not available anymore.')).toList(),
                    ),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Accept'),
                      ),
                    ],
                  ),
                );
              });
            }

            return _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _wishlistProducts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _wishlistProducts.length,
                        itemBuilder: (context, index) {
                          final product = _wishlistProducts[index];
                          return _buildWishlistItem(product);
                        },
                      );
          },
        ),
      ),
    );
  }

  /// Vista cuando la wishlist está vacía
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.heart_slash,
            size: 70,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 20),
          Text(
            "Your wishlist is empty",
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Save products you're interested in here",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 30),
          CupertinoButton(
            color: AppColors.primaryBlue,
            child: Text(
              "Explore Products",
              style: GoogleFonts.inter(color: CupertinoColors.white),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pushNamed('/home');
            },
          ),
        ],
      ),
    );
  }

  /// Construye cada item de la lista
  Widget _buildWishlistItem(ProductModel product) {
    return Dismissible(
      key: Key(product.id ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.systemRed,
        child: const Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.white,
        ),
      ),
      onDismissed: (direction) {
        // Al hacer swipe, se elimina de Firestore y de la lista local
        if (product.id != null) {
          _removeFromWishlistImmediate(product.id!);
        }
      },
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          // Ir a la pantalla de detalles
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: CupertinoColors.systemGrey5),
            ),
          ),
          child: Row(
            children: [
              _buildProductImage(product),
              const SizedBox(width: 12),
              Expanded(child: _buildProductInfo(product)),
              const SizedBox(width: 8),
              _buildHeartIcon(product),
            ],
          ),
        ),
      ),
    );
  }

  /// Imagen del producto
  Widget _buildProductImage(ProductModel product) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: CupertinoColors.systemGrey6,
      ),
      child: product.imageUrls.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                product.imageUrls.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    CupertinoIcons.photo,
                    color: CupertinoColors.systemGrey,
                    size: 30,
                  );
                },
              ),
            )
          : const Icon(
              CupertinoIcons.photo,
              color: CupertinoColors.systemGrey,
              size: 30,
            ),
    );
  }

  /// Info de título, descripción y precio
  Widget _buildProductInfo(ProductModel product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryBlue,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          product.description,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: CupertinoColors.systemGrey,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          "\$${product.price.toStringAsFixed(2)}",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
      ],
    );
  }

  /// Ícono de corazón que refleja si el producto está en la wishlist (rojo)
  /// o si se quitó (outline gris).
  Widget _buildHeartIcon(ProductModel product) {
    final productId = product.id;
    if (productId == null) {
      // Sin ID, no podemos manejar la wishlist
      return const Icon(
        CupertinoIcons.heart_fill,
        color: CupertinoColors.systemRed,
        size: 22,
      );
    }

    // Si está en _removedProductIds => outline, sino => relleno
    final isRemoved = _removedProductIds.contains(productId);

    return GestureDetector(
      onTap: () => _toggleWishlistStatus(product),
      child: Icon(
        isRemoved ? CupertinoIcons.heart : CupertinoIcons.heart_fill,
        color: isRemoved ? CupertinoColors.systemGrey : CupertinoColors.systemRed,
        size: 22,
      ),
    );
  }
}