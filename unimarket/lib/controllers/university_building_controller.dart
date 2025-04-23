import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/models/university_building_model.dart';

// Ensure the UniversityBuilding class is defined in the imported file

class UniversityBuildingController {
  final FirebaseDAO _firebaseDAO = FirebaseDAO();

  // Método para obtener los edificios desde FirebaseDAO y convertirlos en objetos UniversityBuilding
  Future<List<UniversityBuilding>> fetchUniversityBuildings() async {
    try {
      final List<Map<String, dynamic>> buildingMaps = await _firebaseDAO.getUniversityBuildings();

      // Convierte los mapas en objetos UniversityBuilding
      final buildings = buildingMaps.map((map) => UniversityBuilding.fromMap(map)).toList();

      print("Fetched ${buildings.length} university buildings.");
      return buildings;
    } catch (e) {
      print("Error in UniversityBuildingController: $e");
      return [];
    }
  }
}