import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ClientBLEScanner {
  final String serviceUUID = "00001234-0000-1000-8000-00805F9B34FB"; // Same UUID as seller
  bool isSellerNearby = false;

  void startScan() {
    FlutterBluePlus.startScan(timeout: Duration(seconds: 30));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        // Convert the serviceUUID string to a Guid object
        Guid serviceGuid = Guid(serviceUUID);

        // Check if the advertised service UUIDs contain the seller's UUID
        if (result.advertisementData.serviceUuids.contains(serviceGuid)) {
          isSellerNearby = true;
          break;
        }
      }
    });
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
  }
}