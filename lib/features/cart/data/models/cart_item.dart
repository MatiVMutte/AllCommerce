class CartItem {
  const CartItem({
    required this.productId,
    required this.title,
    required this.price,
    this.wholesalePrice,
    this.wholesaleMinQty,
    this.variant,
    this.imageUrl,
    this.quantity = 1,
  });

  final String productId;
  final String title;

  /// Chosen variant ("M", "Rojo") — two lines with the same product but
  /// different variants are separate cart entries.
  final String? variant;

  /// Retail unit price snapshot.
  final double price;

  /// Wholesale unit price + minimum units (null when the product has none).
  final double? wholesalePrice;
  final int? wholesaleMinQty;
  final String? imageUrl;
  final int quantity;

  /// Unique key per line: same product can appear once per variant.
  String get lineKey => '$productId|${variant ?? ''}';

  bool get hasWholesale => wholesalePrice != null && wholesaleMinQty != null;

  /// Whether the quantity already unlocks the wholesale price.
  bool get isWholesaleApplied => hasWholesale && quantity >= wholesaleMinQty!;

  /// Unit price actually charged for this line — wholesale when the
  /// quantity reaches the minimum, never above retail. Mirrors
  /// `place_order`.
  double get unitPrice => isWholesaleApplied
      ? (wholesalePrice! < price ? wholesalePrice! : price)
      : price;

  /// Units missing to unlock the wholesale price (0 when not applicable).
  int get wholesaleMissing => hasWholesale && quantity < wholesaleMinQty!
      ? wholesaleMinQty! - quantity
      : 0;

  double get lineTotal => unitPrice * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final Object? rawWholesale = json['wholesale_price'];
    return CartItem(
      productId: json['product_id'] as String,
      title: json['title'] as String,
      price: num.parse(json['price'].toString()).toDouble(),
      wholesalePrice: rawWholesale == null
          ? null
          : num.tryParse(rawWholesale.toString())?.toDouble(),
      wholesaleMinQty: (json['wholesale_min_qty'] as num?)?.toInt(),
      variant: json['variant'] as String?,
      imageUrl: json['image_url'] as String?,
      quantity: (json['quantity'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'product_id': productId,
      'title': title,
      'price': price,
      'wholesale_price': wholesalePrice,
      'wholesale_min_qty': wholesaleMinQty,
      'variant': variant,
      'image_url': imageUrl,
      'quantity': quantity,
    };
  }

  CartItem copyWith({
    String? productId,
    String? title,
    double? price,
    double? wholesalePrice,
    int? wholesaleMinQty,
    String? variant,
    String? imageUrl,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      title: title ?? this.title,
      price: price ?? this.price,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      wholesaleMinQty: wholesaleMinQty ?? this.wholesaleMinQty,
      variant: variant ?? this.variant,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }
}
