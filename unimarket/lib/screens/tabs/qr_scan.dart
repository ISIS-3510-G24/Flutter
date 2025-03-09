import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';


class QrScan extends StatefulWidget {
  const QrScan({super.key});

  @override
  State<QrScan> createState() => _QrScanState();
}

class _QrScanState extends State<QrScan> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan the QR code on the seller's phone"),
        actions: [
          IconButton(onPressed: (){
            Navigator.popAndPushNamed(context, "/genQR");
          }, 
          icon: const Icon(
            Icons.qr_code
            ),
          )
        ],
      ),
      body: MobileScanner(
        controller: MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          returnImage: true),
        onDetect: (capture){
          final List<Barcode> barcodes = capture.barcodes;
          final Uint8List? image = capture.image;
          for (final barcode in barcodes){
            print('Barcode found! ${barcode.rawValue}');
          }
          if (image != null){
            showDialog(
              context: context, 
              builder: (context){
                return AlertDialog(title: Text(
                    barcodes.first.rawValue ??""
                  ),
                  content:Image(
                    image: MemoryImage(image)
                  ),
                );
              },
            );
          }
        },
      )
    );
  }
}