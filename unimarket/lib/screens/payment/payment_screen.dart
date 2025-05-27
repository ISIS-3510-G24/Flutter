import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/home/home_screen.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:unimarket/services/order_service.dart';
import 'package:unimarket/services/connectivity_service.dart';

class PaymentScreen extends StatefulWidget {
  final String productId;
  final String orderId;

  const PaymentScreen({super.key, required this.productId, required this.orderId});

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final OrderService _orderService = OrderService();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  late StreamSubscription<bool> _connectivitySubscription;
  late StreamSubscription<bool> _checkingSubscription;
  
  bool _hasInternetAccess = true;
  bool _isCheckingConnectivity = false;
  bool _isProcessingPayment = false;
  
  // Payment method selection
  String _selectedPaymentMethod = 'credit_card';
  String _selectedCreditCard = 'mastercard';
  bool _sameAsBillingAddress = true;
  bool _applePayAvailable = true; // Would check actual availability

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _checkingSubscription.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    _hasInternetAccess = _connectivityService.hasInternetAccess;
    _isCheckingConnectivity = _connectivityService.isChecking;

    _connectivitySubscription = _connectivityService.connectivityStream.listen((hasInternet) {
      if (mounted) {
        setState(() {
          _hasInternetAccess = hasInternet;
          // If connection is lost during payment processing, stop it
          if (!hasInternet && _isProcessingPayment) {
            _isProcessingPayment = false;
          }
        });
        
        // Show immediate feedback when connection is lost
        if (!hasInternet && !_isCheckingConnectivity) {
          print("🔴 Connection lost - updating UI");
        } else if (hasInternet) {
          print("🟢 Connection restored - updating UI");
        }
      }
    });

    _checkingSubscription = _connectivityService.checkingStream.listen((isChecking) {
      if (mounted) {
        setState(() {
          _isCheckingConnectivity = isChecking;
        });
        
        if (isChecking) {
          print("🔄 Checking connectivity...");
        }
      }
    });
  }

  void _handleRetryPressed() async {
    print("🔄 Manual retry pressed");
    setState(() {
      _isCheckingConnectivity = true;
    });
    
    bool hasInternet = await _connectivityService.checkConnectivity();
    if (mounted) {
      setState(() {
        _hasInternetAccess = hasInternet;
        _isCheckingConnectivity = false;
      });
      
      if (hasInternet) {
        print("✅ Connection restored successfully");
      } else {
        print("❌ Still no connection available");
      }
    }
  }

  Future<void> _processPayment() async {
    // Double-check connectivity right when button is pressed
    setState(() {
      _isProcessingPayment = true;
    });

    // Force connectivity check before processing
    bool hasInternet = await _connectivityService.checkConnectivity();
    
    if (!hasInternet || !_hasInternetAccess) {
      setState(() {
        _isProcessingPayment = false;
        _hasInternetAccess = false; // Update state immediately
      });
      _showErrorDialog("No Internet Connection", "Please check your internet connection and try again.");
      return;
    }

    try {
      // Simulate processing with periodic connectivity checks
      for (int i = 0; i < 4; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Check connectivity during processing
        bool stillConnected = await _connectivityService.checkConnectivity();
        if (!stillConnected && mounted) {
          setState(() {
            _isProcessingPayment = false;
            _hasInternetAccess = false;
          });
          _showErrorDialog("Connection Lost", "Internet connection was lost during payment processing. Please try again.");
          return;
        }
      }

      // Final connectivity check before completing
      bool finalCheck = await _connectivityService.checkConnectivity();
      if (!finalCheck) {
        setState(() {
          _isProcessingPayment = false;
          _hasInternetAccess = false;
        });
        _showErrorDialog("Connection Lost", "Unable to complete payment due to connection issues. Please try again.");
        return;
      }

      // Update order metrics and status
      await _orderService.updateProductLabelMetrics(widget.orderId);
      await _orderService.updateOrderStatusToPaid(widget.orderId);
      await _orderService.checkWishlistforOrder(widget.orderId);

      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => const ReviewScreen(),
          ),
        );
      }
    } catch (e) {
      print("🚨 Payment processing error: $e");
      _showErrorDialog("Payment Failed", "There was an error processing your payment. Please try again.\n\nError: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withOpacity(0.9),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
        middle: Text(
          "Checkout",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text(
            "Cancel",
            style: TextStyle(color: AppColors.primaryBlue),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Connectivity Banner
            if (!_hasInternetAccess || _isCheckingConnectivity)
              _buildConnectivityBanner(),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress Steps
                    _buildProgressSteps(),
                    
                    const SizedBox(height: 32),
                    
                    // Title and Subtitle
                    Text(
                      "Choose a payment method",
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You won't be charged until you review the order on the next page",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                        height: 1.4,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Payment Methods
                    _buildPaymentMethods(),
                    
                    const SizedBox(height: 24),
                    
                    // Billing Address Toggle
                    _buildBillingAddressToggle(),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Continue Button
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectivityBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CupertinoColors.systemRed.withOpacity(0.1),
            CupertinoColors.systemOrange.withOpacity(0.1),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemRed.withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _isCheckingConnectivity
                ? const CupertinoActivityIndicator(radius: 8)
                : const Icon(
                    CupertinoIcons.wifi_slash,
                    size: 16,
                    color: CupertinoColors.systemRed,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isCheckingConnectivity
                      ? "Checking connection..."
                      : "No internet connection",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.systemRed.darkColor,
                  ),
                ),
                Text(
                  _isCheckingConnectivity
                      ? "Please wait..."
                      : "Payment cannot be processed without internet",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CupertinoColors.systemRed.darkColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          if (!_isCheckingConnectivity)
            CupertinoButton(
              onPressed: _handleRetryPressed,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minSize: 0,
              borderRadius: BorderRadius.circular(6),
              color: CupertinoColors.systemRed.withOpacity(0.2),
              child: Text(
                "Retry",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemRed.darkColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSteps() {
    return Row(
      children: [
        Expanded(child: _buildStepIndicator("Your bag", true)),
        Container(
          width: 40,
          height: 2,
          color: AppColors.primaryBlue,
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),
        Expanded(child: _buildStepIndicator("Payment", true, active: true)),
      ],
    );
  }

  Widget _buildStepIndicator(String title, bool isCompleted, {bool active = false}) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active || isCompleted ? AppColors.primaryBlue : CupertinoColors.systemGrey4,
          ),
          child: Icon(
            isCompleted ? CupertinoIcons.check_mark : CupertinoIcons.circle,
            color: CupertinoColors.white,
            size: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? AppColors.primaryBlue : CupertinoColors.systemGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Credit Card Section
        _buildPaymentMethodSection(
          title: "Credit Card",
          isSelected: _selectedPaymentMethod == 'credit_card',
          onTap: () => setState(() => _selectedPaymentMethod = 'credit_card'),
          child: _selectedPaymentMethod == 'credit_card' ? Column(
            children: [
              const SizedBox(height: 16),
              _buildCreditCardOption(
                cardType: "Mastercard",
                cardNumber: "•••• •••• •••• 1234",
                isSelected: _selectedCreditCard == 'mastercard',
                onTap: () => setState(() => _selectedCreditCard = 'mastercard'),
              ),
              const SizedBox(height: 12),
              _buildCreditCardOption(
                cardType: "Visa",
                cardNumber: "•••• •••• •••• 9876",
                isSelected: _selectedCreditCard == 'visa',
                onTap: () => setState(() => _selectedCreditCard = 'visa'),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.add_circled,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Add new card",
                      style: GoogleFonts.inter(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                onPressed: () {
                  // Show add card dialog
                },
              ),
            ],
          ) : null,
        ),
        
        const SizedBox(height: 16),
        
        // Apple Pay Section
        _buildPaymentMethodSection(
          title: "Apple Pay",
          isSelected: _selectedPaymentMethod == 'apple_pay',
          onTap: _applePayAvailable 
            ? () => setState(() => _selectedPaymentMethod = 'apple_pay')
            : null,
          child: !_applePayAvailable ? Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Apple Pay is not available on this device",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ) : null,
          icon: CupertinoIcons.device_phone_portrait,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection({
    required String title,
    required bool isSelected,
    required VoidCallback? onTap,
    Widget? child,
    IconData? icon,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : CupertinoColors.separator,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primaryBlue : CupertinoColors.systemGrey3,
                      width: 2,
                    ),
                  ),
                  child: isSelected ? Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryBlue,
                    ),
                  ) : null,
                ),
                const SizedBox(width: 12),
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.black,
                  ),
                ),
              ],
            ),
            if (child != null) child,
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCardOption({
    required String cardType,
    required String cardNumber,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppColors.primaryBlue, width: 1) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primaryBlue : CupertinoColors.systemGrey3,
                  width: 2,
                ),
              ),
              child: isSelected ? Container(
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlue,
                ),
              ) : null,
            ),
            const SizedBox(width: 12),
            Icon(
              cardType == "Mastercard" ? CupertinoIcons.creditcard : CupertinoIcons.creditcard_fill,
              color: AppColors.primaryBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              "$cardType $cardNumber",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillingAddressToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CupertinoSwitch(
            value: _sameAsBillingAddress,
            activeColor: AppColors.primaryBlue,
            onChanged: (bool value) {
              setState(() {
                _sameAsBillingAddress = value;
              });
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "My billing address is the same as my shipping address",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    final canProceed = _hasInternetAccess && !_isCheckingConnectivity && !_isProcessingPayment;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: canProceed ? _processPayment : () {
            // Show immediate feedback when tapping disabled button
            if (!_hasInternetAccess) {
              _showErrorDialog("No Internet Connection", "Please check your internet connection and try again.");
            } else if (_isCheckingConnectivity) {
              _showErrorDialog("Checking Connection", "Please wait while we verify your internet connection.");
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: canProceed ? LinearGradient(
                colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryBlue.withOpacity(0.8),
                ],
              ) : null,
              color: canProceed ? null : CupertinoColors.systemGrey4,
              borderRadius: BorderRadius.circular(16),
              boxShadow: canProceed ? [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ] : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessingPayment)
                  const CupertinoActivityIndicator(color: CupertinoColors.white)
                else if (_isCheckingConnectivity)
                  const CupertinoActivityIndicator(color: CupertinoColors.systemGrey)
                else
                  Icon(
                    canProceed ? CupertinoIcons.creditcard : CupertinoIcons.wifi_slash,
                    color: canProceed ? CupertinoColors.white : CupertinoColors.systemGrey,
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Text(
                  _isProcessingPayment 
                    ? "Processing Payment..."
                    : _isCheckingConnectivity
                      ? "Checking Connection..."
                      : !_hasInternetAccess 
                        ? "No Internet Connection"
                        : "Continue",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: canProceed ? CupertinoColors.white : CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white.withOpacity(0.9),
        border: Border.all(color: CupertinoColors.separator, width: 0.5),
        middle: Text(
          "Payment Complete",
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.primaryBlue.withOpacity(0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.check_mark,
                  color: CupertinoColors.white,
                  size: 60,
                ),
              ),
              
              const SizedBox(height: 40),
              
              Text(
                "Payment Successful!",
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                "Your order has been processed successfully.\nYou'll receive a confirmation email shortly.",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.5,
                  color: CupertinoColors.systemGrey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 60),
              
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    CupertinoPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryBlue,
                        AppColors.primaryBlue.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    "Continue Shopping",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}