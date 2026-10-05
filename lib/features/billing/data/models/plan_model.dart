import 'package:all_commerce/core/constants/plans.dart';

/// A sellable plan row from the `plans` table.
class PlanModel {
  const PlanModel({
    required this.id,
    required this.name,
    required this.maxProducts,
    required this.priceArs,
    this.aiAnalysesPerMonth,
    required this.sortOrder,
    required this.highlights,
  });

  final PlanType id;
  final String name;
  final int maxProducts;

  /// Monthly price in ARS; 0 = "Consultar".
  final num priceArs;

  /// Monthly AI analyses cap; null = unlimited.
  final int? aiAnalysesPerMonth;
  final int sortOrder;
  final List<String> highlights;

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: PlanType.fromId(json['id'] as String),
      name: json['name'] as String? ?? '',
      maxProducts: json['max_products'] as int? ?? 0,
      priceArs: json['price_ars'] as num? ?? 0,
      aiAnalysesPerMonth: json['ai_analyses_per_month'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
      highlights: (json['highlights'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
    );
  }
}
