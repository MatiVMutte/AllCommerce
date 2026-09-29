import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({required Object orderNumber}) {
  return <String, dynamic>{
    'id': 'o1',
    'order_number': orderNumber,
    'tenant_id': 't1',
    'customer_id': 'u1',
    'customer_name_snapshot': 'Ana',
    'customer_phone_snapshot': '5491199999999',
    'status': 'pending',
    'subtotal': '25500.00',
    'discount': '0.00',
    'total': '25500.00',
    'coupon_id': null,
    'notes': null,
    'created_at': '2024-01-01T00:00:00.000Z',
  };
}

void main() {
  test('parses order_number as int', () {
    final OrderModel order = OrderModel.fromJson(_json(orderNumber: 42));
    expect(order.orderNumber, 42);
  });

  test('parses numeric fields encoded as strings', () {
    final OrderModel order = OrderModel.fromJson(
      _json(orderNumber: '7'),
    );
    expect(order.orderNumber, 7);
    expect(order.subtotal, 25500);
    expect(order.discount, 0);
    expect(order.total, 25500);
    expect(order.status, 'pending');
  });
}
