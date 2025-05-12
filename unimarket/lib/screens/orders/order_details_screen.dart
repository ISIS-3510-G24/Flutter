import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/payment/payment_screen.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Order Details",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        previousPageTitle: "Back",
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del producto
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    order["image"] ?? "assets/svgs/ImagePlaceHolder.svg",
                    width: 250,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        "assets/svgs/ImagePlaceHolder.svg",
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Título del producto
              Center(
                child: Text(
                  order['name'] ?? "Product Name",
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),

              // Subtítulo del precio
              Center(
                child: Text(
                  order['price'] ?? "N/A",
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.systemGreen,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Separador
              Container(
                height: 1,
                color: CupertinoColors.systemGrey4,
              ),
              const SizedBox(height: 10),

              // Sección de detalles
              Text(
                "Order Information",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue, // Cambiado a azul
                ),
              ),
              const SizedBox(height: 10),
              _buildDetailRow("Order ID", order['orderId'] ?? "N/A"),
              const SizedBox(height: 10),
              _buildDetailRow("Details", order['details'] ?? "N/A"),
              const SizedBox(height: 10),
              _buildDetailRow("Status", order['status'] ?? "N/A"),
              const SizedBox(height: 20),

              // Separador
              Container(
                height: 1,
                color: CupertinoColors.systemGrey4,
              ),
              const SizedBox(height: 20),

              // Botón "Complete" (si aplica)
              if (order['status'] == "Unpaid")
                Center(
                  child: CupertinoButton.filled(
                    onPressed: () {
                      // Acción para completar la orden
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => PaymentScreen(
                            productId: order["productId"],
                            orderId: order["orderId"],
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "Complete Order",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para mostrar filas de detalles
  Widget _buildDetailRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$title:",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              color: CupertinoColors.black,
            ),
          ),
        ),
      ],
    );
  }
}