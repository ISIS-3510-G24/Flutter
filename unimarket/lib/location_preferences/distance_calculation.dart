import 'dart:math';

import 'package:geolocator/geolocator.dart';

class LocationService {
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

    // Obtén la ubicación actual con alta precisión
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Imprime la ubicación actual para depuración
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
}

final List<UniversityBuilding> universityBuildings = [
  UniversityBuilding(
    name: "Q Building",
    latitude: 4.600310063997402,
    longitude: -74.0652599596956,
    relatedLabels: ["Electronics"],
  ),
  UniversityBuilding(
    name: "C Building",
    latitude: 4.601323345591651,
    longitude: -74.06520095111371,
    relatedLabels: [ "Academics"],
  ),
  UniversityBuilding(
    name: "ML Building",
    latitude: 4.60295,
    longitude: -74.06485,
    relatedLabels: ["Accessories"],
  ),

  UniversityBuilding(
    name: "Education Building",
    latitude: 4.601195014481128,
    longitude: -74.06624969475148,
    relatedLabels: ["Accessories"],
  ),
];

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371; // Radio de la Tierra en kilómetros

  double dLat = _degreesToRadians(lat2 - lat1);
  double dLon = _degreesToRadians(lon2 - lon1); // Corregido: lon2 - lon1

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


UniversityBuilding? findNearestBuilding(Position userPosition, {double maxDistance = 1.5}) {
  UniversityBuilding? nearestBuilding;
  double shortestDistance = double.infinity;

  for (var building in universityBuildings) {
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
}