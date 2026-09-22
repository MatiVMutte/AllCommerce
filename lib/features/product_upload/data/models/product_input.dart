class ProductInput {
  const ProductInput({
    required this.title,
    this.description,
    required this.category,
    this.tags = const <String>[],
    required this.price,
    this.sku,
    this.stock = 0,
  });

  final String title;
  final String? description;
  final String category;
  final List<String> tags;
  final double price;
  final String? sku;
  final int stock;
}
