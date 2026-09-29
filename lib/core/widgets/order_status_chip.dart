import 'package:all_commerce/core/constants/order_status.dart';
import 'package:flutter/material.dart';

/// Colored status chip shared by owner and customer order lists.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = status.color(Theme.of(context).colorScheme);
    return Chip(
      label: Text(status.label),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color),
      side: BorderSide.none,
    );
  }
}
