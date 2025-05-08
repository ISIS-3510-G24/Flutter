import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unimarket/screens/ble_scan/client_BLE_Scanner.dart';
import 'package:unimarket/screens/qr/qr_scan.dart';
import 'package:unimarket/theme/app_colors.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/data/sqlite_user_dao.dart';

class ClientScreenScan extends StatefulWidget {
  const ClientScreenScan({super.key});
  
  @override
  ClientScreenState createState() => ClientScreenState();
}

class ClientScreenState extends State<ClientScreenScan> {
  final ClientBLEScanner _bleScanner = ClientBLEScanner();
  Map<String, String>? _hashAndOrders;
  bool _isButtonEnabled = false;

  @override
void initState() {
  super.initState();
  _fetchOrders();
  _startScanning();
}

  void _startScanning() {
    _bleScanner.startScan();
  
    Future.delayed(Duration(seconds: 2), _checkForSellerDevice);
  }

  void _checkForSellerDevice() {
    setState(() {
      _isButtonEnabled = _bleScanner.isSellerNearby;
    });

    if (!_isButtonEnabled) {
      Future.delayed(Duration(seconds: 2), _checkForSellerDevice);
    }
  }
  Future<void> _fetchOrders() async {
  final dao = FirebaseDAO();
  final sqliteDAO = SQLiteUserDAO();

  try {
    final data = await dao.getProductsForCurrentBUYER();
    await sqliteDAO.saveOrderInfoMap(data);
    setState(() {
      _hashAndOrders = data;
    });
  } catch (e) {
    try {
      final data = await sqliteDAO.getAllOrderInfo();
      setState(() {
        _hashAndOrders = data;
      });
    } catch (_) {
      _showErrorDialog("Network Error", "Please verify your internet connection and try again");
    }
  }
}

  @override
  void dispose() {
    _bleScanner.stopScan();
    super.dispose();
  }

  
@override
Widget build(BuildContext context) {
  return CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: Text('Go near your product seller to continue'),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoButton(
            onPressed: _isButtonEnabled && _hashAndOrders != null
              ? () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => QrScan(hashAndOrders: _hashAndOrders!),
                    ),
                  );
                }
              : null,
            color: _isButtonEnabled ? CupertinoColors.white : CupertinoColors.inactiveGray,
            child: Text('Proceed to Scan QR'),
          ),
          SizedBox(height: 20),
          if (!_isButtonEnabled)
            Text(
                    "To be able to confirm a product delivery, you must be near the product seller. Looking for the seller's device...",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0x00000000),
                    ),
                  )
          else
          Text(
                    "Device Found!",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0x00000000),
                    ),
                  ),
          if (!_isButtonEnabled)
            SpinKitSpinningLines(color: AppColors.primaryBlue,size: 60.0), 
        ],
      ),
    ),
  );
}
void _showErrorDialog(String title, String message) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoButton(
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
}