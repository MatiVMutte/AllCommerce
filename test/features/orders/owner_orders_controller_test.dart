import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/repositories/order_repository.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

OrderModel _order({
  String id = 'o1',
  int number = 42,
  OrderStatus status = OrderStatus.requested,
  String name = 'Ana López',
  String phone = '5491199999999',
}) {
  return OrderModel(
    id: id,
    orderNumber: number,
    tenantId: 't1',
    customerId: 'u1',
    customerNameSnapshot: name,
    customerPhoneSnapshot: phone,
    status: status,
    subtotal: 100,
    discount: 0,
    total: 100,
    createdAt: DateTime(2025),
  );
}

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

  test('changeStatus calls updateStatus and returns updated order', () async {
    final OrderModel updated = _order().copyWith(status: OrderStatus.preparing);
    when(() => repo.updateStatus('o1', 't1', OrderStatus.preparing))
        .thenAnswer((_) async => updated);
    when(() => repo.notifyCustomer(updated)).thenAnswer((_) async {});

    final OrderModel? result = await container
        .read(ownerOrdersControllerProvider.notifier)
        .changeStatus(_order(), OrderStatus.preparing);

    expect(result?.status, OrderStatus.preparing);
    expect(container.read(ownerOrdersControllerProvider).busyOrderId, isNull);
    verify(() => repo.updateStatus('o1', 't1', OrderStatus.preparing))
        .called(1);
  });

  test('changeStatus error sets state.error and returns null', () async {
    when(() => repo.updateStatus('o1', 't1', OrderStatus.rejected))
        .thenThrow(Exception('boom'));

    final OrderModel? result = await container
        .read(ownerOrdersControllerProvider.notifier)
        .changeStatus(_order(), OrderStatus.rejected);

    expect(result, isNull);
    expect(container.read(ownerOrdersControllerProvider).error, isNotNull);
  });

  test('filterOrders by status and query', () {
    final List<OrderModel> orders = <OrderModel>[
      _order(name: 'Ana López'),
      _order(
        id: 'o2',
        number: 43,
        status: OrderStatus.preparing,
        name: 'José Pérez',
      ),
    ];
    expect(filterOrders(orders, status: OrderStatus.preparing).single.id, 'o2');
    expect(filterOrders(orders, query: '#42').single.id, 'o1');
    // accent-insensitive name search
    expect(filterOrders(orders, query: 'jose').single.id, 'o2');
    expect(filterOrders(orders, query: 'zzz'), isEmpty);
  });

  test('pendingCount counts requested orders', () {
    final List<OrderModel> orders = <OrderModel>[
      _order(),
      _order(id: 'o2', number: 43),
      _order(id: 'o3', number: 44, status: OrderStatus.delivered),
    ];
    expect(pendingCount(orders), 2);
  });
}
