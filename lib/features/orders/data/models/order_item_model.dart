class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.orderId,
    this.productId,
    required this.titleSnapshot,
    required this.unitPrice,
    this.listPrice = 0,
    required this.quantity,
    this.variant,
    this.unit = 'unidad',
  });

  final String id;
  final String orderId;

  /// Null when the product was deleted (`on delete set null`).
  final String? productId;
  final String titleSnapshot;
  final double unitPrice;

  /// Product's regular price at order time. `listPrice > unitPrice` means
  /// the line was charged the wholesale price.
  final double listPrice;
  final double quantity;

  /// Variant the customer picked ("M", "Rojo"), if the product has them.
  final String? variant;

  /// Sellable unit at order time ('unidad', 'kg'...) — snapshot.
  final String unit;

  double get lineTotal => unitPrice * quantity;

  /// Whether this line got the wholesale price (unit below list price).
  bool get isWholesale => listPrice > unitPrice + 0.005;

  /// What the line would have cost at list price (wholesale savings base).
  double get listLineTotal => listPrice * quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String?,
      titleSnapshot: json['title_snapshot'] as String,
      unitPrice: num.parse(json['unit_price'].toString()).toDouble(),
      listPrice:
          num.tryParse(json['list_price']?.toString() ?? '0')?.toDouble() ?? 0,
      quantity: (json['quantity'] as num).toDouble(),
      variant: json['variant'] as String?,
      unit: (json['unit'] as String?) ?? 'unidad',
    );
  }
}
