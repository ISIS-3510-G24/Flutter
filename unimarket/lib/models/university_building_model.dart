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

  // Método para convertir un objeto UniversityBuilding a un mapa
  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "latitude": latitude,
      "longitude": longitude,
      "relatedLabels": relatedLabels,
    };
  }
}