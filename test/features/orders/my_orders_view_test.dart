import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:all_commerce/features/orders/presentation/views/my_orders_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final TenantModel tenant = TenantModel(
    id: 't1',
    slug: 'demo',
    name: 'Demo Store',
    whatsapp: '5491122334455',
    primaryColor: '#0052FF',
    plan: PlanType.trial,
    trialStartedAt: DateTime(2025),
    planExpiresAt: DateTime.now().add(const Duration(days: 10)),
    isActive: true,
      isClaimed: true,
    createdAt: DateTime(2025),
  );

  final OrderModel order = OrderModel(
    id: 'o1',
    orderNumber: 42,
    tenantId: 't1',
    customerId: 'u1',
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
        myOrdersProvider.overrideWith((Ref ref) async => orders),
        tenantByIdProvider('t1')
            .overrideWith((Ref ref) async => tenant),
      ],
      child: const MaterialApp(home: MyOrdersView()),
    );
  }

  testWidgets('shows order with store name and status chip',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildView(orders: <OrderModel>[order]));
    await tester.pumpAndSettle();

    expect(find.text('#42 · Demo Store'), findsOneWidget);
    expect(find.text('Solicitado'), findsOneWidget);
  });

  testWidgets('empty list shows empty state', (WidgetTester tester) async {
    await tester.pumpWidget(buildView(orders: <OrderModel>[]));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hiciste pedidos'), findsOneWidget);
    expect(find.text('Ver locales'), findsOneWidget);
  });
}
