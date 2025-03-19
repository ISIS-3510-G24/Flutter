import 'package:flutter/cupertino.dart';
import 'package:unimarket/screens/ble_scan/client_BLE_Scanner.dart';
import 'package:unimarket/theme/app_colors.dart';

class ClientScreenScan extends StatefulWidget {
  const ClientScreenScan({super.key});
  
  @override
  ClientScreenState createState() => ClientScreenState();
}

class ClientScreenState extends State<ClientScreenScan> {
  final ClientBLEScanner _bleScanner = ClientBLEScanner();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
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
              onPressed: _isButtonEnabled
                  ? () {
                      Navigator.pushNamed(context, '/scanQR');
                    }
                  : null,
              color: _isButtonEnabled ? AppColors.primaryBlue: CupertinoColors.inactiveGray,
              child: Text('Proceed to Scan QR'),
            ),
          ],
        ),
      ),
    );
  }
}