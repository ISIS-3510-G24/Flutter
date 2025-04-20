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

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
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
    name: "ML Building",
    latitude: 4.655397867262984,
    longitude: -74.10943295187545,
    relatedLabels: ["Accesories"],
  ),
  UniversityBuilding(
    name: "Library",
    latitude: 37.7750,
    longitude: -122.4183,
    relatedLabels: [ "Academics"],
  ),
  UniversityBuilding(
    name: "Sports Complex",
    latitude: 37.7760,
    longitude: -122.4170,
    relatedLabels: ["Electronics"],
  ),
];

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


UniversityBuilding findNearestBuilding(Position userPosition) {
  UniversityBuilding? nearestBuilding;
  double shortestDistance = double.infinity;

  for (var building in universityBuildings) {
    double distance = calculateDistance(
      userPosition.latitude,
      userPosition.longitude,
      building.latitude,
      building.longitude,
    );

    if (distance < shortestDistance) {
      shortestDistance = distance;
      nearestBuilding = building;
    }
  }

  return nearestBuilding!;
}