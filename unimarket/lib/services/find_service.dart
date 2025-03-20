import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/find_model.dart';
import 'package:unimarket/models/offer_model.dart';

class FindService {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  Future<List<FindModel>> getFind() async {
    return await _firebaseDAO.getFind();
  }

  Future<List<OfferModel>> getOffersForFind(String findId) async {
    return await _firebaseDAO.getOffersForFind(findId);
  }
}