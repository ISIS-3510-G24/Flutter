import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/home/home_screen.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/services/order_service.dart';
import 'package:unimarket/screens/tabs/orders_screen.dart'; // Importa OrdersScreen

class PaymentScreen extends StatelessWidget {
  final String productId;
  final String orderId;
  final OrderService _orderService = OrderService();

  PaymentScreen({super.key, required this.productId, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Checkout",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text(
            "Cancel",
            style: GoogleFonts.inter(color: AppColors.primaryBlue),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepIndicator("Your bag", true),
                  const SizedBox(width: 20), 
                  _buildStepIndicator("Payment", true, active: true),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                "Choose a payment method",
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You won't be charged until you review the order on the next page",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 20),
              _buildPaymentMethodSection(),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: double.infinity, // Ancho completo
                  child: CupertinoButton(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                    child: Text(
                      "Continue",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.white,
                      ),
                    ),
                    onPressed: () async {
                      // Actualizar las métricas de labels
                      _orderService.updateProductLabelMetrics(orderId);
                      // Actualizar el estado del producto en Firestore usando el servicio
                      await _orderService.updateOrderStatusToPaid(orderId);
                      _orderService.checkWishlistforOrder(orderId);
                      // Navegar a la pantalla de revisión
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => ReviewScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(String title, bool isCompleted, {bool active = false}) {
    return Flexible(
      child: Column(
        children: [
          Icon(
            isCompleted ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
            color: active ? AppColors.primaryBlue : isCompleted ? AppColors.primaryBlue : CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: active ? AppColors.primaryBlue : isCompleted ? AppColors.primaryBlue : CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPaymentMethodOption("Credit Card", [
          _buildCreditCardOption("Mastercard", "xxxx xxxx xxxx 1234", true),
          _buildCreditCardOption("Visa", "xxxx xxxx xxxx 9876", false),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Text(
              "+ Add new card",
              style: GoogleFonts.inter(color: AppColors.primaryBlue),
            ),
            onPressed: () {
              // Acción para añadir una nueva tarjeta
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildPaymentMethodOption("Apple Pay", []),
        const SizedBox(height: 20),
        Row(
          children: [
            CupertinoSwitch(
              value: true,
              onChanged: (bool value) {
                // Acción para cambiar el estado del switch
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "My billing address is the same as my shipping address",
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentMethodOption(String title, List<Widget> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: options,
          ),
        ),
      ],
    );
  }

  Widget _buildCreditCardOption(String cardType, String cardNumber, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isSelected ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
            color: isSelected ? AppColors.primaryBlue : CupertinoColors.systemGrey,
          ),
          const SizedBox(width: 8),
          Text(
            "$cardType $cardNumber",
            style: GoogleFonts.inter(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class ReviewScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          "Review",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.check_mark_circled_solid,
                  color: AppColors.primaryBlue,
                  size: 100,
                ),
                const SizedBox(height: 20),
                Text(
                  "Successful payment",
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Your payment has been processed successfully",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                CupertinoButton(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(12),
                  child: Text(
                    "Accept",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      CupertinoPageRoute(builder: (context) => HomeScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}