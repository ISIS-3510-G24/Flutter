import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unimarket/models/find_model.dart';
import 'package:unimarket/models/offer_model.dart';

class FindService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<FindModel>> getFinds() async {
    try {
      final snapshot = await _firestore.collection('finds').get();
      return snapshot.docs.map((doc) => FindModel.fromFirestore(doc.data(), doc.id)).toList();
    } catch (e) {
      print("Error fetching finds: $e");
      return [];
    }
  }

  Future<List<OfferModel>> getOffersForFind(String findId) async {
    try {
      final snapshot = await _firestore.collection('finds').doc(findId).collection('offers').get();
      return snapshot.docs.map((doc) => OfferModel.fromFirestore(doc.data(), doc.id)).toList();
    } catch (e) {
      print("Error fetching offers for find: $e");
      return [];
    }
  }
}