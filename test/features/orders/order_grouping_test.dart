import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/order_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OrderModel order(String id, DateTime at) => OrderModel(
    id: id,
    orderNumber: 1,
    tenantId: 't1',
    customerId: 'u1',
    customerNameSnapshot: 'Ana',
    customerPhoneSnapshot: '1',
    status: OrderStatus.requested,
    subtotal: 1,
    discount: 0,
    total: 1,
    createdAt: at,
  );

  final DateTime now = DateTime(2025, 9, 24, 15); // Mié 24 sep 2025

  test('groups today, yesterday and older dates', () {
    final List<OrderDayGroup> groups = groupOrdersByDay(<OrderModel>[
      order('a', now),
      order('b', now.subtract(const Duration(hours: 2))),
      order('c', now.subtract(const Duration(days: 1))),
      order('d', DateTime(2025, 9, 22, 10)), // Lun 22 sep
    ], now: now);
    expect(groups.length, 3);
    expect(groups[0].label, 'Hoy');
    expect(groups[0].orders.map((OrderModel o) => o.id), <String>['a', 'b']);
    expect(groups[1].label, 'Ayer');
    expect(groups[2].label, 'Lun 22 sep');
  });

  test('empty input gives no groups', () {
    expect(groupOrdersByDay(<OrderModel>[], now: now), isEmpty);
  });
}
