import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class SellerBLEAdvertiser {
  final FlutterBlePeripheral peripheral = FlutterBlePeripheral();
  final String serviceUUID = "00001234-0000-1000-8000-00805F9B34FB"; 

  Future<void> startAdvertising() async {
    // Create AdvertiseData
    AdvertiseData advertiseData = AdvertiseData(
      serviceUuid: serviceUUID, 
      includeDeviceName: true, 
    );
    AdvertiseSettings advertiseSettings = AdvertiseSettings(
      advertiseMode: AdvertiseMode.advertiseModeLowPower, 
      timeout: 0, // 0 means no timeout
      connectable: true, // Allow connections
      txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium, 
    );

    // Start advertising
    await peripheral.start(
      advertiseData: advertiseData,
      advertiseSettings: advertiseSettings,
    );
    print("Seller device is advertising...");
  }

  Future<void> stopAdvertising() async {
    await peripheral.stop();
    print("Seller device stopped advertising.");
  }
}