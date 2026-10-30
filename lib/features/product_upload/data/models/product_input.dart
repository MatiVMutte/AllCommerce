class ProductInput {
  const ProductInput({
    required this.title,
    this.description,
    required this.category,
    this.tags = const <String>[],
    required this.price,
    this.compareAtPrice,
    this.wholesalePrice,
    this.wholesaleMinQty,
    this.sku,
    this.stock = 0,
    this.trackStock = false,
  });

  final String title;
  final String? description;
  final String category;
  final List<String> tags;
  final double price;
  final double? compareAtPrice;

  /// Wholesale unit price when the buyer takes [wholesaleMinQty]+ units.
  final double? wholesalePrice;
  final int? wholesaleMinQty;
  final String? sku;
  final int stock;
  final bool trackStock;
}
