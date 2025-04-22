import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:unimarket/data/firebase_dao.dart';

class LocationService {

  LocationService._privateConstructor();
  // Singleton instance
  static final _instance = LocationService._privateConstructor();
  // Factory constructor to return the same instance
  // This ensures that every time someone calls LocationService(), they will get the same instance
  factory LocationService() {
    return _instance;
  }


  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions are denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    print("Current location: Latitude: ${position.latitude}, Longitude: ${position.longitude}");
    return position;
  }
}


class UniversityBuilding {
  final String name;
  final double latitude;
  final double longitude;
  final List<String> relatedLabels;

  UniversityBuilding({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.relatedLabels,
  });

  // Método para crear un objeto UniversityBuilding desde un mapa
  factory UniversityBuilding.fromMap(Map<String, dynamic> data) {
    return UniversityBuilding(
      name: data['name'] ?? '',
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      relatedLabels: List<String>.from(data['relatedLabels'] ?? []),
    );
  }
}

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371; // Radio de la Tierra en kilómetros

  double dLat = _degreesToRadians(lat2 - lat1);
  double dLon = _degreesToRadians(lon2 - lon1);

  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degreesToRadians(double degrees) {
  return degrees * pi / 180;
}

Future<UniversityBuilding?> findNearestBuilding(Position userPosition, {double maxDistance = 1.5}) async {
  final firebaseDAO = FirebaseDAO();

  try {
    // Obtén los edificios desde Firebase
    final buildingMaps = await firebaseDAO.getUniversityBuildings();

    // Convierte los mapas en objetos UniversityBuilding
    final buildings = buildingMaps.map((map) => UniversityBuilding.fromMap(map)).toList();

    UniversityBuilding? nearestBuilding;
    double shortestDistance = double.infinity;

    for (var building in buildings) {
      double distance = calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        building.latitude,
        building.longitude,
      );

      print("Building name: ${building.name}, Distance: $distance km");

      if (distance < shortestDistance && distance <= maxDistance) {
        shortestDistance = distance;
        nearestBuilding = building;
      }
    }

    if (nearestBuilding != null) {
      print("Nearest building: ${nearestBuilding.name}, Distance: $shortestDistance km");
    } else {
      print("No buildings within $maxDistance km.");
    }

    return nearestBuilding;
  } catch (e) {
    print("Error finding nearest building: $e");
    return null;
  }
}