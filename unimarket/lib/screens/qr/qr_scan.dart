import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/data/sqlite_user_dao.dart';
import 'package:unimarket/screens/tabs/profile_screen.dart';
import 'package:unimarket/services/offline_queue_service.dart';


class QrScan extends StatefulWidget {
  final Map<String, String> hashAndOrders;

  const QrScan({Key? key, required this.hashAndOrders}) : super(key: key);

  @override
  State<QrScan> createState() => _QrScanState();
}

class _QrScanState extends State<QrScan> {
  //Aplica el patrón de DAO
  final FirebaseDAO _firebaseDAO = FirebaseDAO(); 
  late Map<String, String>? _hashAndOrders;
  final sqliteUserDAO = SQLiteUserDAO();
  final OfflineQueueService _offlineQueueService = OfflineQueueService();
  //bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _hashAndOrders = widget.hashAndOrders;
    //_fetchHashes();
    if (_hashAndOrders != null) {
      print("Printing hashAndOrders contents:");
      
    } else {
      print("hashAndOrders is null");
    }
  }

  Future<void> _fetchHashes() async {
    try {
      final hashAndOrders = await _firebaseDAO.getProductsForCurrentBUYER();
      //Guardarlas en BD relacional (SQLITE) para futuro uso
      await sqliteUserDAO.saveOrderInfoMap(hashAndOrders);
      setState(() {
        _hashAndOrders = hashAndOrders;
        //_isLoading = false;
      });
    } catch (e) {
      print("Error fetching products, will try getting from local storage");
      try
        {
          final hashAndOrders = await sqliteUserDAO.getAllOrderInfo();
          setState(() {
            _hashAndOrders = hashAndOrders;
            //_isLoading = false;
          });
        }
      catch (er){
        print("ERROR fetching sqscan data from SQLITE");
        _showErrorDialog("Network Error","Please verify your internet connection and try again");
      }
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
            _hashAndOrders!.forEach((key, value) {
              print("Hash: $key -> Order ID: $value, Barcode scanned: ${barcode.rawValue}, is it the same?: ${barcode.rawValue == key}");
            });

            final hashConfirm = barcode.rawValue;
            if (hashConfirm != null && (_hashAndOrders!.containsKey(hashConfirm) ||_hashAndOrders!.containsValue(hashConfirm) )) {
              final orderId = _hashAndOrders![hashConfirm];
              print("Order ID obtained: $orderId");
              print("debugging hashes");

              _hashAndOrders?.forEach((hashConfirm, productID) {
                print("hashConfirm: $hashConfirm, productID: $productID");
              });
              if (orderId != null) {
                _firebaseDAO.updateOrderStatusDelivered(orderId,hashConfirm).then((_) {
                _showSuccessDialog();
                }).catchError((e) {
                  // si no se puede por falta de internet, mandarlo al Shared Preferences storage compartido
                _offlineQueueService.addOrderToQueue(orderId,hashConfirm,);
                _showOfflineSuccessDialog();
                });
              }
            }
            //NO ENCUENTRA EL HASHCODE QUE ES 
            else {
            _showErrorDialog("Invalid QR Scanned","The QR code is invalid, please try again.");
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


/*
flutter: Printing hashAndOrders contents:
flutter: Barcode found! B2480s98ssme11b9xx30c7f72784e6b0
flutter: Hash: B2480c97debe99b5bb30c7f72784e6b0 -> Order ID: PjR4maicGtvFmm1kzSXF, Barcode scanned: B2480s98ssme11b9xx30c7f72784e6b0, is it the same?: false
flutter: Hash: a1936b97debe99b5bb30c7f72784e6b0 -> Order ID: k264oSAnuGZx2YqR8Cfx, Barcode scanned: B2480s98ssme11b9xx30c7f72784e6b0, is it the same?: false
flutter: Hash: a1936b97debe99b5bb30c7f72784i8c9 -> Order ID: tqYlCyQZDVmA8IBGOok9, Barcode scanned: B2480s98ssme11b9xx30c7f72784e6b0, is it the same?: false

*/