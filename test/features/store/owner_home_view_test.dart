import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/billing/data/repositories/ai_usage_repository.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:all_commerce/features/store/presentation/views/owner_home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOwnerProducts extends OwnerProductsNotifier {
  _FakeOwnerProducts(this.items) : super('t1');

  final List<ProductModel> items;

  @override
  Future<List<ProductModel>> build() async => items;
}

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

  final UserModel owner = UserModel(
    id: 'u1',
    tenantId: 't1',
    role: UserRole.owner,
    fullName: 'Dueño Demo',
    createdAt: DateTime(2025),
  );

  final List<ProductModel> products = <ProductModel>[
    ProductModel(
      id: 'p1',
      tenantId: 't1',
      title: 'P1',
      category: 'home',
      price: 100,
      isActive: true,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
    ProductModel(
      id: 'p2',
      tenantId: 't1',
      title: 'P2',
      category: 'home',
      price: 100,
      isActive: true,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
  ];

  final List<OrderModel> orders = <OrderModel>[
    OrderModel(
      id: 'o1',
      orderNumber: 42,
      tenantId: 't1',
      customerId: 'u2',
      customerNameSnapshot: 'Ana',
      customerPhoneSnapshot: '549111',
      status: OrderStatus.requested,
      subtotal: 100,
      discount: 0,
      total: 100,
      createdAt: DateTime(2025),
    ),
  ];

  testWidgets('panel shows name, product counter and new orders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith((Ref ref) async => owner),
          tenantByIdProvider('t1').overrideWith((Ref ref) async => tenant),
          ownerProductsProvider('t1')
              .overrideWith(() => _FakeOwnerProducts(products)),
          ownerOrdersProvider('t1').overrideWith((Ref ref) async => orders),
          aiUsageProvider.overrideWith(
            (Ref ref) async => const AiUsage(used: 12, limit: 60),
          ),
        ],
        child: const MaterialApp(home: OwnerHomeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo Store'), findsOneWidget);
    expect(find.text('2/30'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('Pedidos nuevos'), findsOneWidget);
    expect(find.textContaining('Plan Prueba'), findsOneWidget);
  });
}
