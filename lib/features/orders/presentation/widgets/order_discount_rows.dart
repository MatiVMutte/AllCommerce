import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:flutter/material.dart';

/// Discount lines of an order's money summary:
/// "Cupón (CODE) −$500", "Descuento por volumen (10%) −$X",
/// "Descuento por pago (Efectivo · 5%) −$Y", plus shipping when it applies.
///
/// Orders placed before the breakdown was persisted fall back to a single
/// generic "Descuento" line so old receipts keep adding up.
class OrderCostRows extends StatelessWidget {
  const OrderCostRows({required this.order, this.dense = false, super.key});

  final OrderModel order;

  /// Compact variant used inside the expandable customer order card.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final List<(String, double)> entries = <(String, double)>[
      if (order.couponDiscount > 0)
        (
          order.couponCode == null ? 'Cupón' : 'Cupón (${order.couponCode})',
          order.couponDiscount,
        ),
      if (order.bulkDiscount > 0)
        (
          'Descuento por volumen (${order.bulkDiscountPct.round()}%)',
          order.bulkDiscount,
        ),
      if (order.paymentDiscount > 0)
        (
          'Descuento por pago (${order.paymentMethod.label} · '
              '${order.paymentDiscountPct.round()}%)',
          order.paymentDiscount,
        ),
      if (entriesAreEmpty(order) && order.discount > 0)
        ('Descuento', order.discount),
    ];

    return Column(
      children: <Widget>[
        for (final (String label, double amount) in entries)
          _Row(
            label: label,
            amount: '−${Formatters.price(amount)}',
            dense: dense,
            color: tokens.success,
          ),
        if (order.deliveryCost > 0)
          _Row(
            label: 'Envío',
            amount: Formatters.price(order.deliveryCost),
            dense: dense,
            color: tokens.textSecondary,
          ),
      ],
    );
  }

  static bool entriesAreEmpty(OrderModel order) =>
      order.couponDiscount <= 0 &&
      order.bulkDiscount <= 0 &&
      order.paymentDiscount <= 0;
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.amount,
    required this.dense,
    required this.color,
  });

  final String label;
  final String amount;
  final bool dense;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: dense ? 4 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: dense ? 12 : 13, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: dense ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
