class ProductModel {
  final String id;
  final String name;
  final String description;
  final int price;
  final int quantity;
  final int availability;
  final List<String> characteristics;
  final String imageUrl;
  final int views;
  final int classId;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    required this.availability,
    required this.characteristics,
    required this.imageUrl,
    required this.views,
    required this.classId,
  });

  factory ProductModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ProductModel(
      id: id,
      name: data['Prod_Name'] ?? 'No Name',
      description: data['Prod_Description'] ?? '',
      price: data['Prod_Price'] ?? 0,
      quantity: data['Prod_Quantity'] ?? 0,
      availability: data['Prod_Availability'] ?? 0,
      characteristics: List<String>.from(data['Prod_Characteristics'] ?? []),
      imageUrl: data['Prod_image'] ?? '',
      views: data['Views'] ?? 0,
      classId: data['class_id'] ?? 0,
    );
  }
}
