class CartItem {
  const CartItem({
    required this.productId,
    required this.title,
    required this.price,
    this.imageUrl,
    this.quantity = 1,
  });

  final String productId;
  final String title;
  final double price;
  final String? imageUrl;
  final int quantity;

  double get lineTotal => price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['product_id'] as String,
      title: json['title'] as String,
      price: num.parse(json['price'].toString()).toDouble(),
      imageUrl: json['image_url'] as String?,
      quantity: (json['quantity'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'product_id': productId,
      'title': title,
      'price': price,
      'image_url': imageUrl,
      'quantity': quantity,
    };
  }

  CartItem copyWith({
    String? productId,
    String? title,
    double? price,
    String? imageUrl,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      title: title ?? this.title,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }
}
