import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/screens/payment/payment_screen.dart';
import 'package:unimarket/services/connectivity_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final ConnectivityService _connectivityService = ConnectivityService();
  late StreamSubscription<bool> _connectivitySubscription;
  late StreamSubscription<bool> _checkingSubscription;

  bool _hasInternetAccess = true;
  bool _isCheckingConnectivity = false;

  @override
  void initState() {
    super.initState();

    // Inicializa el estado de conectividad
    _hasInternetAccess = _connectivityService.hasInternetAccess;
    _isCheckingConnectivity = _connectivityService.isChecking;

    // Escucha cambios en la conectividad
    _connectivitySubscription = _connectivityService.connectivityStream.listen((hasInternet) {
      if (mounted) {
        setState(() {
          _hasInternetAccess = hasInternet;
        });
      }
    });

    // Escucha cambios en el estado de verificación
    _checkingSubscription = _connectivityService.checkingStream.listen((isChecking) {
      if (mounted) {
        setState(() {
          _isCheckingConnectivity = isChecking;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _checkingSubscription.cancel();
    super.dispose();
  }

  void _handleRetryPressed() async {
    // Forzar una verificación de conectividad
    bool hasInternet = await _connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _hasInternetAccess = hasInternet;
      });
    }
  }

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
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Banner de conectividad
                if (!_hasInternetAccess || _isCheckingConnectivity)
                  Container(
                    width: double.infinity,
                    color: CupertinoColors.systemYellow.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      children: [
                        _isCheckingConnectivity
                            ? const CupertinoActivityIndicator(radius: 8)
                            : const Icon(
                                CupertinoIcons.exclamationmark_triangle,
                                size: 16,
                                color: CupertinoColors.systemYellow,
                              ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isCheckingConnectivity
                                ? "Checking internet connection..."
                                : "You are offline. Some features may not work.",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                        if (!_isCheckingConnectivity)
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            onPressed: _handleRetryPressed,
                            child: Text(
                              "Retry",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
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
                              widget.order["image"] ?? "assets/svgs/ImagePlaceHolder.svg",
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
                            widget.order['name'] ?? "Product Name",
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
                            widget.order['price'] ?? "N/A",
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
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow("Order ID", widget.order['orderId'] ?? "N/A"),
                        const SizedBox(height: 10),
                        _buildDetailRow("Details", widget.order['details'] ?? "N/A"),
                        const SizedBox(height: 10),
                        _buildDetailRow("Status", widget.order['status'] ?? "N/A"),
                        const SizedBox(height: 20),

                        // Separador
                        Container(
                          height: 1,
                          color: CupertinoColors.systemGrey4,
                        ),
                        const SizedBox(height: 20),

                        // Botón "Complete" (si aplica)
                        if (widget.order['status'] == "Unpaid")
                          Center(
                            child: CupertinoButton.filled(
                              onPressed: () {
                                if (!_hasInternetAccess) {
                                  showCupertinoDialog(
                                    context: context,
                                    builder: (ctx) => CupertinoAlertDialog(
                                      title: const Text("No Internet"),
                                      content: const Text("You need an internet connection to complete the order."),
                                      actions: [
                                        CupertinoDialogAction(
                                          child: const Text("OK"),
                                          onPressed: () => Navigator.pop(ctx),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (context) => PaymentScreen(
                                        productId: widget.order["productId"],
                                        orderId: widget.order["orderId"],
                                      ),
                                    ),
                                  );
                                }
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
              ],
            ),
          ),
        ],
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