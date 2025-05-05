import 'package:unimarket/models/product_model.dart';

/// Elemento que viaja en la cola offline – persistido en Hive/SharedPrefs
class QueuedProductModel {
  final String       queueId;
  final ProductModel product;
  final String       status;          // queued | uploading | completed | failed
  final DateTime     queuedTime;
  final String?      errorMessage;
  final int          retryCount;

  QueuedProductModel({
    required this.queueId,
    required this.product,
    required this.status,
    required this.queuedTime,
    this.errorMessage,
    this.retryCount = 0,
  });

  // ── (De)serialización ────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'queueId'     : queueId,
        'product'     : product.toJson(),
        'status'      : status,
        'queuedTime'  : queuedTime.toIso8601String(),
        'errorMessage': errorMessage,
        'retryCount'  : retryCount,
      };

  factory QueuedProductModel.fromJson(Map<String, dynamic> json) =>
      QueuedProductModel(
        queueId     : json['queueId'],
        product     : ProductModel.fromJson(json['product']),
        status      : json['status'],
        queuedTime  : DateTime.parse(json['queuedTime']),
        errorMessage: json['errorMessage'],
        retryCount  : json['retryCount'] ?? 0,
      );

  // ── copia segura ─────────────────────────────────────────────────────────
  QueuedProductModel copyWith({
    String?       queueId,
    ProductModel? product,
    String?       status,
    DateTime?     queuedTime,
    String?       errorMessage,
    int?          retryCount,
  }) =>
      QueuedProductModel(
        queueId     : queueId     ?? this.queueId,
        product     : product     ?? this.product,
        status      : status      ?? this.status,
        queuedTime  : queuedTime  ?? this.queuedTime,
        errorMessage: errorMessage ?? this.errorMessage,
        retryCount  : retryCount  ?? this.retryCount,
      );
}
