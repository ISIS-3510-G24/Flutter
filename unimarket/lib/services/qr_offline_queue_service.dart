import 'package:hive/hive.dart';

class OfflineQueueService {
  static const _queueBoxName = 'pending_order_updates';
  static Box<Map>? _box;

  // Initialize with app-level Hive setup
  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(_TypeIds.update)) {
      Hive.registerAdapter(UpdateRecordAdapter());
    }
    _box = await Hive.openBox<Map>(_queueBoxName);
  }

  // Model for queued updates
  static Future<void> addOrderUpdate({
    required String orderId,
    required String hashConfirm,
  }) async {
    await _ensureBoxOpen();
    await _box!.add({
      'type': 'order_delivered',
      'orderId': orderId,
      'hashConfirm': hashConfirm,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map>> getPendingOrderUpdates() async {
    await _ensureBoxOpen();
    return _box!.values.where((item) => item['type'] == 'order_delivered').toList();
  }

  static Future<void> removeOrderUpdate(int index) async {
    await _ensureBoxOpen();
    await _box!.deleteAt(index);
  }
    static Future<void> addUpdate({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final box = Hive.box<Map>(_queueBoxName);
    await box.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> clearAllOrderUpdates() async {
    await _ensureBoxOpen();
    await _box!.clear();
  }

  // Private helper to ensure box is open
  static Future<void> _ensureBoxOpen() async {
    _box ??= await Hive.openBox<Map>(_queueBoxName);
  }

  // Dispose when no longer needed
  static Future<void> dispose() async {
    await _box?.close();
    _box = null;
  }
}

// Adapter for type safety
class UpdateRecordAdapter extends TypeAdapter<Map> {
  @override
  final typeId = _TypeIds.update;

  @override
  Map read(BinaryReader reader) {
    return reader.readMap();
  }

  @override
  void write(BinaryWriter writer, Map obj) {
    writer.writeMap(obj);
  }
}

// Unique type IDs for all Hive adapters in your app
class _TypeIds {
  static const int update = 15;
  //static const int user = 2; 
  //static const int product = 2; 
  // Add more as needed, ensuring each service uses unique IDs
}