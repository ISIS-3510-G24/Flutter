import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/screens/tabs/profile_screen.dart';
import 'package:unimarket/services/qr_offline_queue_service.dart';
class QrScan extends StatefulWidget {
  const QrScan({super.key});

  @override
  State<QrScan> createState() => _QrScanState();
}

class _QrScanState extends State<QrScan> {
  //Aplica el patrón de DAO
  final FirebaseDAO _firebaseDAO = FirebaseDAO(); 
  Map<String, String>? _hashAndOrders;
  //bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHashes();
  }

  Future<void> _fetchHashes() async {
    try {
      final hashAndOrders = await _firebaseDAO.getProductsForCurrentBUYER();
      setState(() {
        _hashAndOrders = hashAndOrders;
        //_isLoading = false;
      });
    } catch (e) {
      print("Error fetching products: $e");
      setState(() {
        //_isLoading = false;
      });
    }
  }
@override
Widget build(BuildContext context) {
  return CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: const Text("Scan the QR code on the seller's phone"),
    ),
    child: MobileScanner(
      controller: MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: true,
      ),
      onDetect: (capture) async {
        final List<Barcode> barcodes = capture.barcodes;

        for (final barcode in barcodes) {
          final hashConfirm = barcode.rawValue;
          if (hashConfirm != null && _hashAndOrders!.containsKey(hashConfirm)) {
            final orderId = _hashAndOrders![hashConfirm];
            
            if (orderId != null) {
              try {
                // Try online update first
                await _firebaseDAO.updateOrderStatusDelivered(orderId, hashConfirm);
                _showSuccessDialog();
              } catch (e) {
                // If offline, save to Hive queue
                await OfflineQueueService.addOrderUpdate(
                  orderId: orderId,
                  hashConfirm: hashConfirm,
                );
                _showOfflineSuccessDialog();
              }
            }
          } else {
            _showErrorDialog("The QR code is invalid, try again.");
          }
        }
      },
    ),
  );
}

void _showSuccessDialog() {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text("Successful Delivery"),
      content: const Text("The order has been delivered successfully."),
      actions: [
        CupertinoButton(
          child: const Text('OK'),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute(builder: (context) => ProfileScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ],
    ),
  );
}

void _showOfflineSuccessDialog() {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text("Delivery Recorded Offline"),
      content: const Text("Currently there is no internet connection, but the purchase will be validated as soon as the device goes back online."),
      actions: [
        CupertinoButton(
          child: const Text('OK'),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              CupertinoPageRoute(builder: (context) => ProfileScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ],
    ),
  );
}

void _showErrorDialog(String message) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text("Error"),
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