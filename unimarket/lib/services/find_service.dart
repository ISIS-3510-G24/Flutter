import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/find_model.dart';
import 'package:unimarket/models/offer_model.dart';

class FindService {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  // Get all finds
  Future<List<FindModel>> getFind() async {
    return await _firebaseDAO.getFind();
  }

  // Get finds by major
  Future<List<FindModel>> getFindsByMajor(String major) async {
    return await _firebaseDAO.getFindsByMajor(major);
  }

  // Get current user's major
  Future<String?> getCurrentUserMajor() async {
    return await _firebaseDAO.getUserMajor();
  }

  // Get offers for a specific find
  Future<List<OfferModel>> getOffersForFind(String findId) async {
    return await _firebaseDAO.getOffersForFind(findId);
  }

  // Create a new find
  Future<void> createFind({
    required String title,
    required String description,
    String? image,
    required String major,
    required List<String> labels,
  }) async {
    await _firebaseDAO.createFind(
      title: title,
      description: description,
      image: image,
      major: major,
      labels: labels,
    );
  }

  // Create a new offer
  Future<void> createOffer({
    required String findId,
    required String userName,
    required String description,
    String? image,
    required double price, 
  }) async {
    await _firebaseDAO.createOffer(
      findId: findId,
      userName: userName,
      description: description,
      image: image,
      price: price,
    );
  }
}