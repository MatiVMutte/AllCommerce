class OrderModel {
  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.tenantId,
    required this.customerId,
    required this.customerNameSnapshot,
    required this.customerPhoneSnapshot,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.couponId,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final int orderNumber;
  final String tenantId;
  final String customerId;
  final String customerNameSnapshot;
  final String customerPhoneSnapshot;
  final String status;
  final double subtotal;
  final double discount;
  final double total;
  final String? couponId;
  final String? notes;
  final DateTime createdAt;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      orderNumber: num.parse(json['order_number'].toString()).toInt(),
      tenantId: json['tenant_id'] as String,
      customerId: json['customer_id'] as String,
      customerNameSnapshot: json['customer_name_snapshot'] as String,
      customerPhoneSnapshot: json['customer_phone_snapshot'] as String,
      status: json['status'] as String,
      subtotal: num.parse(json['subtotal'].toString()).toDouble(),
      discount: num.parse(json['discount'].toString()).toDouble(),
      total: num.parse(json['total'].toString()).toDouble(),
      couponId: json['coupon_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
