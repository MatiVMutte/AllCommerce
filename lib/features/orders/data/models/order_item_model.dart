class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.orderId,
    this.productId,
    required this.titleSnapshot,
    required this.unitPrice,
    required this.quantity,
    this.variant,
  });

  final String id;
  final String orderId;

  /// Null when the product was deleted (`on delete set null`).
  final String? productId;
  final String titleSnapshot;
  final double unitPrice;
  final int quantity;

  /// Variant the customer picked ("M", "Rojo"), if the product has them.
  final String? variant;

  double get lineTotal => unitPrice * quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String?,
      titleSnapshot: json['title_snapshot'] as String,
      unitPrice: num.parse(json['unit_price'].toString()).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      variant: json['variant'] as String?,
    );
  }
}
