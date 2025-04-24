class RecommendationModel {
  final String productId;
  final String name;
  final List<String> tags;
  final String image;
  final double price;

  RecommendationModel({
    required this.productId,
    required this.name,
    required this.tags,
    required this.image,
    required this.price,
  });

  factory RecommendationModel.fromMap(Map<String, dynamic> map) {
    return RecommendationModel(
      productId: map['productId'],
      name: map['name'],
      tags: List<String>.from(map['tags']),
      image: map['image'],
      price: map['price'].toDouble(),
    );
  }
}