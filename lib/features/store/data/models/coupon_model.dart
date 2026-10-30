/// Discount coupon owned by a tenant (e.g. PROMO10 → 10% off).
class CouponModel {
  const CouponModel({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.discountPercent,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String code;
  final int discountPercent;
  final bool isActive;
  final DateTime createdAt;

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      code: json['code'] as String,
      discountPercent: (json['discount_percent'] as num).toInt(),
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
