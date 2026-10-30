import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/features/cart/data/models/cart_item.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/repositories/order_repository.dart';
import 'package:all_commerce/features/orders/presentation/view_models/checkout_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

OrderModel _order() {
  return OrderModel(
    id: 'o1',
    orderNumber: 42,
    tenantId: 't1',
    customerId: 'u1',
    customerNameSnapshot: 'Ana',
    customerPhoneSnapshot: '5491199999999',
    status: OrderStatus.requested,
    subtotal: 100,
    discount: 0,
    total: 100,
    createdAt: DateTime(2024),
  );
}

const List<CartItem> _items = <CartItem>[
  CartItem(productId: 'p1', title: 'X', price: 100, quantity: 1),
];

void main() {
  late MockOrderRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockOrderRepository();
    container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('successful placeOrder sets order and clears sending', () async {
    when(
      () => repo.placeOrder(
        tenantId: any(named: 'tenantId'),
        items: any(named: 'items'),
        couponCode: any(named: 'couponCode'),
        notes: any(named: 'notes'),
      ),
    ).thenAnswer((_) async => _order());

    final OrderModel? result = await container
        .read(checkoutControllerProvider.notifier)
        .placeOrder(tenantId: 't1', items: _items);

    expect(result?.orderNumber, 42);
    final CheckoutState state = container.read(checkoutControllerProvider);
    expect(state.order?.orderNumber, 42);
    expect(state.sending, isFalse);
    expect(state.error, isNull);
  });

  test('PostgrestException sets error and sending=false', () async {
    when(
      () => repo.placeOrder(
        tenantId: any(named: 'tenantId'),
        items: any(named: 'items'),
        couponCode: any(named: 'couponCode'),
        notes: any(named: 'notes'),
      ),
    ).thenThrow(const PostgrestException(message: 'PHONE_REQUIRED'));

    final OrderModel? result = await container
        .read(checkoutControllerProvider.notifier)
        .placeOrder(tenantId: 't1', items: _items);

    expect(result, isNull);
    final CheckoutState state = container.read(checkoutControllerProvider);
    expect(state.order, isNull);
    expect(state.sending, isFalse);
    expect(state.error, isA<PostgrestException>());
  });
}
