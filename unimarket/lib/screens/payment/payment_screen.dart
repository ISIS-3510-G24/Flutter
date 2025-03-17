import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentScreen extends StatelessWidget {
  final String productId;
  final String orderId;

  const PaymentScreen({super.key, required this.productId, required this.orderId});

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
                  const SizedBox(width: 20), 
                  _buildStepIndicator("Shipping", false),
                  const SizedBox(width: 20), 
                  _buildStepIndicator("Review", false),
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
                      // Actualizar el estado del producto en Firestore
                      await FirebaseFirestore.instance
                          .collection('orders')
                          .doc(orderId)
                          .update({'status': 'Payment'});

                      // Navegar a la siguiente pantalla de revisión
                      Navigator.pop(context);
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