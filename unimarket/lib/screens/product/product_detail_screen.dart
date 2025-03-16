import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/models/product_model.dart';
import 'package:unimarket/theme/app_colors.dart';

class ProductDetailScreen extends StatelessWidget {
  final ProductModel product;

  const ProductDetailScreen({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Product Details",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80), // Add padding to avoid overlap with the button
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  _buildProductImage(product),
                  
                  // Product Details
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Price Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Expanded(
                              child: Text(
                                product.title,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Price
                            Text(
                              _formatPrice(product.price),
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: product.status == "Available" 
                                ? AppColors.primaryBlue.withOpacity(0.2) 
                                : CupertinoColors.systemGrey4,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product.status,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: product.status == "Available" 
                                  ? AppColors.primaryBlue 
                                  : CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Description
                        Text(
                          "Description",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.description,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Labels Section
                        Text(
                          "Tags",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildLabelsRow(product.labels),
                        
                        const SizedBox(height: 24),
                        
                        // Additional Info
                        Text(
                          "Additional Information",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow("Major", product.majorID),
                        _buildInfoRow("Posted on", _formatDate(product.createdAt)),
                        _buildInfoRow("Updated", _formatDate(product.updatedAt)),
                        _buildInfoRow("ID", product.classId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    borderRadius: BorderRadius.circular(30),
                    child: Text(
                      "Contact Seller",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.white,
                      ),
                    ),
                    onPressed: () {
                      print("Contacting seller: ${product.sellerID}");
                      // Add your contact logic here
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProductImage(ProductModel product) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
      ),
      child: product.imageUrls.isNotEmpty 
          ? Image.network(
              product.imageUrls.first,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: SvgPicture.asset(
                    "assets/svgs/ImagePlaceHolder.svg",
                    height: 100,
                    width: 100,
                  ),
                );
              },
            )
          : Center(
              child: SvgPicture.asset(
                "assets/svgs/ImagePlaceHolder.svg",
                height: 100,
                width: 100,
              ),
            ),
    );
  }
  
  Widget _buildLabelsRow(List<String> labels) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.map((label) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.lightGreyBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
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
  
  String _formatDate(DateTime date) {
    // Format: Month Day, Year at Hour:Minute AM/PM
    String month = _getMonthName(date.month);
    String hour = date.hour > 12 ? (date.hour - 12).toString() : date.hour.toString();
    String minute = date.minute.toString().padLeft(2, '0');
    String period = date.hour >= 12 ? 'PM' : 'AM';
    
    return "$month ${date.day}, ${date.year} at $hour:$minute $period";
  }
  
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}