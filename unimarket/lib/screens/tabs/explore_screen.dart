import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/product/product_upload.dart';
import 'package:unimarket/widgets/buttons/floating_action_button_factory.dart';
import 'package:unimarket/widgets/popups/not_implemented.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/upload/confirm_product_screen.dart';
import 'package:unimarket/screens/product/product_detail_screen.dart';

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
  // Create a trace for the product loading operation
  final Trace productLoadTrace = FirebasePerformance.instance.newTrace('products_fetch_time');
  
  // Start the trace
  await productLoadTrace.start();
  
  try {
    List<ProductModel> allProducts = await _productService.fetchAllProducts();
    List<ProductModel> filteredProducts = await _productService.fetchProductsByMajor();
    
    // Add metrics for the number of products fetched
    productLoadTrace.setMetric('all_products_count', allProducts.length.toInt());
    productLoadTrace.setMetric('filtered_products_count', filteredProducts.length.toInt());
    
    if (mounted) {
      setState(() {
        _allProducts = allProducts;
        _filteredProducts = filteredProducts;
        _isLoading = false;
      });
    }
  } catch (e) {
    // Add an attribute for error if it occurs
    productLoadTrace.putAttribute('error', e.toString());
    print("Error loading products: $e");
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  } finally {
    // Stop the trace - this will send the data to Firebase
    await productLoadTrace.stop();
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
  
  // Muestra un modal con un campo de búsqueda
  void _showSearchModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        // Focus node to auto-focus the search field when modal opens
        final FocusNode _searchFocus = FocusNode();
        
        // Auto-focus after the modal is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).requestFocus(_searchFocus);
        });
        
        return Container(
          color: CupertinoColors.systemBackground,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoSearchTextField(
                focusNode: _searchFocus,
                onSubmitted: (value) {
                  print("Search query: $value");
                  // Implement search functionality here
                  Navigator.pop(ctx);
                },
                placeholder: "Search products...",
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
          onPressed: _showSearchModal,
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
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: product.imageUrls.isNotEmpty
                                                        ? Image.network(
                                                            product.imageUrls.first,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return SvgPicture.asset(
                                                                "assets/svgs/ImagePlaceHolder.svg",
                                                                fit: BoxFit.cover,
                                                              );
                                                            },
                                                          )
                                                        : SvgPicture.asset(
                                                            "assets/svgs/ImagePlaceHolder.svg",
                                                            fit: BoxFit.cover,
                                                          ),
                                                  ),
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
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: product.imageUrls.isNotEmpty
                                                        ? Image.network(
                                                            product.imageUrls.first,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return SvgPicture.asset(
                                                                "assets/svgs/ImagePlaceHolder.svg",
                                                                fit: BoxFit.cover,
                                                              );
                                                            },
                                                          )
                                                        : SvgPicture.asset(
                                                            "assets/svgs/ImagePlaceHolder.svg",
                                                            fit: BoxFit.cover,
                                                          ),
                                                  ),
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