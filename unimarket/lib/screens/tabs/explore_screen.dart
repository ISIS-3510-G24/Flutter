import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/widgets/popups/not_implemented.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/upload/confirm_product_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ProductService _productService = ProductService();
  List<ProductModel> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      List<ProductModel> products = await _productService.fetchProducts();
      if (mounted) {
        setState(() {
          _products = products;
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Explore",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
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
                      : _products.isEmpty
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
                                      itemCount: _products.length,
                                      itemBuilder: (context, index) {
                                        final product = _products[index];
                                        return GestureDetector(
                                          onTap: () {
                                            print("Clicked on ${product.title}");
                                            // Navigate to product detail screen
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
                                                  "\$${product.price.toStringAsFixed(2)}",
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

          // Floating button fixed at the bottom
          Positioned(
            right: 20,
            bottom: 20,
            child: CupertinoButton(
              color: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              borderRadius: BorderRadius.circular(30),
              child: Text(
                "Upload Product",
                style: GoogleFonts.inter(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (ctx) => const ConfirmProductScreen(postType: "offer"),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}