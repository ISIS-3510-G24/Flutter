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

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ProductService _productService = ProductService();
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      List<ProductModel> allProducts = await _productService.fetchAllProducts();
      List<ProductModel> filteredProducts = await _productService.fetchProductsByMajor();
      if (mounted) {
        setState(() {
          _allProducts = allProducts;
          _filteredProducts = filteredProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading products: $e");
      if (mounted) {
        setState(() {
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
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _navigateToSearch,
          child: const Icon(
            CupertinoIcons.search,
            size: 26,
            color: AppColors.primaryBlue,
          ),
        ),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
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
                          : SingleChildScrollView(
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
                                    child: GridView.builder(
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