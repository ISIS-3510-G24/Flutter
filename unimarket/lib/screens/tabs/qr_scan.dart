import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:unimarket/screens/patterns/firebase_dao.dart';

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
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;

          for (final barcode in barcodes) {
            print('Barcode found! ${barcode.rawValue}');
            final hashConfirm = barcode.rawValue;
            if (hashConfirm != null && _hashAndOrders!.containsKey(hashConfirm)) {
              final orderId = _hashAndOrders![hashConfirm];
              if (orderId != null) {
                _firebaseDAO.updateOrderStatusDelivered(orderId).then((_) {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) {
                      return CupertinoAlertDialog(
                        title: const Text("Successful Delivery"),
                        content: const Text("The order has been delivered successfully. You can close this view now."),
                        actions: [
                          CupertinoButton(
                            child: const Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                }).catchError((e) {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) {
                      return CupertinoAlertDialog(
                        title: const Text("Error"),
                        content: Text("Failed to update order status: $e"),
                        actions: [
                          CupertinoButton(
                            child: const Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                });
              }
            }
            //NO ENCUENTRA EL HASHCODE QUE ES 
            else {
              showCupertinoDialog(
                context: context,
                builder: (context) {
                  return CupertinoAlertDialog(
                    title: const Text("Invalid QR Code"),
                    content: const Text("The QR code is invalid, try again."),
                    actions: [
                      CupertinoButton(
                        child: const Text('OK'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            }
          }
        },
      ),
    );
  }
}