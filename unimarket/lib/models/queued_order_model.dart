import 'package:unimarket/models/product_model.dart';

/// Elemento que viaja en la cola offline – persistido en Hive/SharedPrefs
class QueuedOrderModel {
  final String       queueId;
  final String       orderID;
  final String       hashConfirm;  
  final String       status;              // queued | uploading | completed | failed        
  final DateTime     queuedTime;
  final String?      errorMessage;
  final int          retryCount;

  QueuedOrderModel({
    required this.queueId,
    required this.orderID,
    required this.hashConfirm,
    required this.status,
    required this.queuedTime,
    this.errorMessage,
    this.retryCount = 0,
  });

  // ── (De)serialización ────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'queueId'     : queueId,
        'orderID'     : orderID,
        'hashConfirm' : hashConfirm,
        'status'      : status,
        'queuedTime'  : queuedTime.toIso8601String(),
        'errorMessage': errorMessage,
        'retryCount'  : retryCount,
      };

  factory QueuedOrderModel.fromJson(Map<String, dynamic> json) =>
    QueuedOrderModel(
      queueId     : json['queueId'],
      orderID     : json['orderID'],
      hashConfirm : json['hashConfirm'],
      status      : json['status'],
      queuedTime  : DateTime.parse(json['queuedTime']),
      errorMessage: json['errorMessage'],
      retryCount  : json['retryCount'] ?? 0,
    );

  // ── copia segura ─────────────────────────────────────────────────────────
  QueuedOrderModel copyWith({
  String? queueId,
  String? orderID,
  String? hashConfirm,
  String? status,
  DateTime? queuedTime,
  String? errorMessage,
  int? retryCount,
}) =>
    QueuedOrderModel(
      queueId     : queueId     ?? this.queueId,
      orderID     : orderID     ?? this.orderID,
      hashConfirm : hashConfirm ?? this.hashConfirm,
      status      : status      ?? this.status,
      queuedTime  : queuedTime  ?? this.queuedTime,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount  : retryCount  ?? this.retryCount,
    );
}
