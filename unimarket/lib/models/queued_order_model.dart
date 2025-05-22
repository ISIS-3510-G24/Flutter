class QueuedOrderModel {
  final String queueId;
  final String orderID;
  final String hashConfirm;
  final String status; // queued | processing | completed | failed
  final DateTime queuedTime;
  final int retryCount;
  final String? errorMessage;

  QueuedOrderModel({
    required this.queueId,
    required this.orderID,
    required this.hashConfirm,
    required this.status,
    required this.queuedTime,
    this.retryCount = 0,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'queueId': queueId,
        'orderID': orderID,
        'hashConfirm': hashConfirm,
        'status': status,
        'queuedTime': queuedTime.toIso8601String(),
        'retryCount': retryCount,
        'errorMessage': errorMessage,
      };

  factory QueuedOrderModel.fromJson(Map<String, dynamic> json) =>
      QueuedOrderModel(
        queueId: json['queueId'],
        orderID: json['orderID'],
        hashConfirm: json['hashConfirm'],
        status: json['status'],
        queuedTime: DateTime.parse(json['queuedTime']),
        retryCount: json['retryCount'] ?? 0,
        errorMessage: json['errorMessage'],
      );

  QueuedOrderModel copyWith({
    String? queueId,
    String? orderID,
    String? hashConfirm,
    String? status,
    DateTime? queuedTime,
    int? retryCount,
    String? errorMessage,
  }) =>
      QueuedOrderModel(
        queueId: queueId ?? this.queueId,
        orderID: orderID ?? this.orderID,
        hashConfirm: hashConfirm ?? this.hashConfirm,
        status: status ?? this.status,
        queuedTime: queuedTime ?? this.queuedTime,
        retryCount: retryCount ?? this.retryCount,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}