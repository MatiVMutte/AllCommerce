import 'package:all_commerce/core/utils/formatters.dart';

/// Discount coupon owned by a tenant (e.g. PROMO10 → 10% off or $500 off).
class CouponModel {
  const CouponModel({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.discountType,
    this.discountPercent,
    this.discountAmount,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String code;

  /// 'percent' or 'fixed'.
  final String discountType;
  final int? discountPercent;
  final double? discountAmount;
  final bool isActive;
  final DateTime createdAt;

  bool get isPercent => discountType == 'percent';

  /// "−10%" / "−$500".
  String get discountLabel => isPercent
      ? '−${discountPercent ?? 0}%'
      : '−${Formatters.price(discountAmount ?? 0)}';

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      code: json['code'] as String,
      discountType: (json['discount_type'] as String?) ?? 'percent',
      discountPercent: (json['discount_percent'] as num?)?.toInt(),
      discountAmount: json['discount_amount'] == null
          ? null
          : num.parse(json['discount_amount'].toString()).toDouble(),
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
