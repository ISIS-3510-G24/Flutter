import 'package:flutter/foundation.dart';
import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/university_building_model.dart';

class UniversityBuildingController {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  Future<List<UniversityBuilding>> fetchUniversityBuildings() async {
    try {
      final List<Map<String, dynamic>> buildingMaps = await _firebaseDAO.getUniversityBuildings();

      // Usamos compute para convertir los mapas en un isolate
      final buildings = await compute(_parseBuildings, buildingMaps);

      print("Fetched ${buildings.length} university buildings.");
      return buildings;
    } catch (e) {
      print("Error in UniversityBuildingController: $e");
      return [];
    }
  }
}

// Esta función corre en un isolate separado como multithreading strategy
List<UniversityBuilding> _parseBuildings(List<Map<String, dynamic>> maps) {
  return maps.map((map) => UniversityBuilding.fromMap(map)).toList();
}
