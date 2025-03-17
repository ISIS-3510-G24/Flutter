import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/order_model.dart';

class OrderService {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  Future<void> updateOrderStatusToPaid(String orderId) async {
    await _firebaseDAO.updateOrderStatus(orderId, 'Purchased');
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    return await _firebaseDAO.getOrderById(orderId);
  }
}