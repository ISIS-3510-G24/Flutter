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
    latitude: 37.7749,
    longitude: -122.4194,
    relatedLabels: ["Electronics", "Engineering", "Technology"],
  ),
  UniversityBuilding(
    name: "Library",
    latitude: 37.7750,
    longitude: -122.4183,
    relatedLabels: ["Books", "Education", "Academics"],
  ),
  UniversityBuilding(
    name: "Sports Complex",
    latitude: 37.7760,
    longitude: -122.4170,
    relatedLabels: ["Sports", "Fitness", "Accessories"],
  ),
];