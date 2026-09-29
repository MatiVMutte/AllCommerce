import 'package:all_commerce/core/constants/order_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromId falls back to requested', () {
    expect(OrderStatus.fromId('preparing'), OrderStatus.preparing);
    expect(OrderStatus.fromId('nope'), OrderStatus.requested);
  });

  test('nextOptions follow the status flow', () {
    expect(
      OrderStatus.requested.nextOptions,
      <OrderStatus>[
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.rejected,
      ],
    );
    expect(
      OrderStatus.preparing.nextOptions,
      <OrderStatus>[OrderStatus.ready, OrderStatus.rejected],
    );
    expect(
      OrderStatus.ready.nextOptions,
      <OrderStatus>[OrderStatus.delivered, OrderStatus.rejected],
    );
    expect(OrderStatus.delivered.nextOptions, isEmpty);
    expect(OrderStatus.rejected.nextOptions, isEmpty);
  });

  test('isFinal only for delivered and rejected', () {
    expect(OrderStatus.delivered.isFinal, isTrue);
    expect(OrderStatus.rejected.isFinal, isTrue);
    expect(OrderStatus.requested.isFinal, isFalse);
    expect(OrderStatus.preparing.isFinal, isFalse);
    expect(OrderStatus.ready.isFinal, isFalse);
  });
}
