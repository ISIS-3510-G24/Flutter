import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String buyerId;
  final String sellerId;
  final String productId;
  final DateTime orderDate;
  final String status;
  final double price;
  final String hashConfirm;

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.orderDate,
    required this.status,
    required this.price,
    required this.hashConfirm,
  });

  factory OrderModel.fromFirestore(Map<String, dynamic> data, String id) {
    return OrderModel(
      id: id,
      buyerId: data['buyerID'] ?? '',
      sellerId: data['sellerID'] ?? '',
      productId: data['productID'] ?? '',
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'Pending',
      price: data['price']?.toDouble() ?? 0.0,
      hashConfirm: data['hashConfirm'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'buyerID': buyerId,
      'sellerID': sellerId,
      'productID': productId,
      'orderDate': orderDate,
      'status': status,
      'price': price,
      'hashConfirm': hashConfirm,
    };
  }
}