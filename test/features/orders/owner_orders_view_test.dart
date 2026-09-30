import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:all_commerce/features/orders/presentation/views/owner_orders_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final UserModel owner = UserModel(
    id: 'u1',
    tenantId: 't1',
    role: UserRole.owner,
    fullName: 'Dueño Demo',
    createdAt: DateTime(2025),
  );

  final OrderModel order = OrderModel(
    id: 'o1',
    orderNumber: 42,
    tenantId: 't1',
    customerId: 'u2',
    customerNameSnapshot: 'Ana López',
    customerPhoneSnapshot: '5491199999999',
    status: OrderStatus.requested,
    subtotal: 100,
    discount: 0,
    total: 100,
    createdAt: DateTime(2025),
  );

  Widget buildView({required List<OrderModel> orders}) {
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((Ref ref) async => owner),
        ownerOrdersProvider('t1')
            .overrideWith((Ref ref) async => orders),
      ],
      child: const MaterialApp(home: OwnerOrdersView()),
    );
  }

  testWidgets('shows order tile with number, name and status chip',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildView(orders: <OrderModel>[order]));
    await tester.pumpAndSettle();

    expect(find.text('#42'), findsOneWidget);
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('Solicitado'), findsWidgets);
  });

  testWidgets('empty list shows empty state', (WidgetTester tester) async {
    await tester.pumpWidget(buildView(orders: <OrderModel>[]));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no recibiste pedidos'), findsOneWidget);
  });
}
