/// Monthly sales snapshot for the owner dashboard, returned by the
/// `owner_sales_metrics` RPC. Only non-rejected orders are counted.
class SalesMetrics {
  const SalesMetrics({
    required this.monthTotal,
    required this.monthCount,
    required this.prevTotal,
    required this.prevCount,
    required this.topProducts,
  });

  final double monthTotal;
  final int monthCount;
  final double prevTotal;
  final int prevCount;
  final List<SalesTopProduct> topProducts;

  /// Percent change vs the previous month, or null when there is no
  /// meaningful baseline (prev month had no sales).
  double? get monthOverMonthDelta {
    if (prevTotal <= 0) return null;
    return (monthTotal - prevTotal) / prevTotal * 100;
  }

  factory SalesMetrics.fromJson(Map<String, dynamic> json) {
    return SalesMetrics(
      monthTotal: num.parse(json['month_total'].toString()).toDouble(),
      monthCount: num.parse(json['month_count'].toString()).toInt(),
      prevTotal: num.parse(json['prev_total'].toString()).toDouble(),
      prevCount: num.parse(json['prev_count'].toString()).toInt(),
      topProducts: (json['top_products'] as List<dynamic>)
          .map(
            (dynamic e) =>
                SalesTopProduct.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class SalesTopProduct {
  const SalesTopProduct({
    required this.title,
    required this.quantity,
    required this.revenue,
  });

  final String title;
  final int quantity;
  final double revenue;

  factory SalesTopProduct.fromJson(Map<String, dynamic> json) {
    return SalesTopProduct(
      title: json['title'] as String,
      quantity: num.parse(json['qty'].toString()).toInt(),
      revenue: num.parse(json['revenue'].toString()).toDouble(),
    );
  }
}
