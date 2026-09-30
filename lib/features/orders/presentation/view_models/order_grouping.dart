import 'package:all_commerce/features/orders/data/models/order_model.dart';

/// A section of orders that share the same calendar day.
class OrderDayGroup {
  const OrderDayGroup({required this.label, required this.orders});

  /// 'Hoy', 'Ayer', or 'Lun 23 sep'.
  final String label;
  final List<OrderModel> orders;
}

const List<String> _weekdays = <String>[
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom',
];
const List<String> _months = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Groups [orders] (already sorted desc) into day sections with
/// Spanish labels. [now] is injectable for tests.
List<OrderDayGroup> groupOrdersByDay(
  List<OrderModel> orders, {
  DateTime? now,
}) {
  final DateTime ref = now ?? DateTime.now();
  final DateTime today = DateTime(ref.year, ref.month, ref.day);
  final List<OrderDayGroup> groups = <OrderDayGroup>[];
  final Map<String, OrderDayGroup> byKey = <String, OrderDayGroup>{};
  for (final OrderModel order in orders) {
    final DateTime d = order.createdAt.toLocal();
    final DateTime day = DateTime(d.year, d.month, d.day);
    final String label;
    if (day == today) {
      label = 'Hoy';
    } else if (day == today.subtract(const Duration(days: 1))) {
      label = 'Ayer';
    } else {
      label =
          '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
    }
    final String key = _dayKey(day);
    final OrderDayGroup? existing = byKey[key];
    if (existing == null) {
      final OrderDayGroup group =
          OrderDayGroup(label: label, orders: <OrderModel>[order]);
      byKey[key] = group;
      groups.add(group);
    } else {
      existing.orders.add(order);
    }
  }
  return groups;
}
