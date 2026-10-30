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
    this.variants = const <String>[],
    this.unit = 'unidad',
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
  final double? wholesaleMinQty;
  final String? sku;

  /// Store-defined options the buyer picks one of ("S", "M", "L", "Rojo").
  final List<String> variants;

  /// Sellable unit ('unidad', 'kg'...). Non-'unidad' units accept
  /// fractional quantities.
  final String unit;
  final double stock;
  final bool trackStock;
}
