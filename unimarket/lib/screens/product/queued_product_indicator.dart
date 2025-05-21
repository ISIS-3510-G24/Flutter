import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/models/queued_product_model.dart';
import 'package:unimarket/services/product_service.dart';
import 'package:unimarket/services/offline_queue_service.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/product/queued_products_screen.dart';

class QueuedProductIndicator extends StatelessWidget {
  const QueuedProductIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final ProductService productService = ProductService();
    
    return StreamBuilder<List<QueuedProductModel>>(
      stream: productService.queuedProductsStream,
      builder: (context, snapshot) {
        final queuedProducts = snapshot.data ?? [];
        
        // Filtrar para obtener sólo elementos pendientes (no completados)
        final pendingProducts = queuedProducts.where((item) => 
          item.status != 'completed').toList();
        
        if (pendingProducts.isEmpty) {
          return SizedBox.shrink(); // Ocultar si no hay productos pendientes
        }
        
        // Contar por estado
        final queuedCount = pendingProducts.where((p) => p.status == 'queued').length;
        final uploadingCount = pendingProducts.where((p) => p.status == 'uploading').length;
        final failedCount = pendingProducts.where((p) => p.status == 'failed').length;
        
        return GestureDetector(
          onTap: () {
            // Navegar a la pantalla de productos en cola
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => QueuedProductsScreen(),
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.arrow_up_doc,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${pendingProducts.length} producto${pendingProducts.length == 1 ? '' : 's'} en cola",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          if (uploadingCount > 0)
                            _buildStatusBadge(
                              "$uploadingCount subiendo", 
                              AppColors.primaryBlue
                            ),
                          if (queuedCount > 0)
                            _buildStatusBadge(
                              "$queuedCount en cola", 
                              CupertinoColors.systemOrange
                            ),
                          if (failedCount > 0)
                            _buildStatusBadge(
                              "$failedCount con error", 
                              CupertinoColors.systemRed
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}