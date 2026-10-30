import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:all_commerce/features/store/presentation/views/owner_products_view.dart';
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

  ProductModel product({required String id, required bool active}) =>
      ProductModel(
        id: id,
        tenantId: 't1',
        title: 'Producto $id',
        category: 'home',
        price: 100,
        isActive: active,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );

  Widget buildView({required List<ProductModel> items}) {
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((Ref ref) async => owner),
        tenantByIdProvider('t1').overrideWith((Ref ref) async => tenant),
        ownerProductsProvider('t1')
            .overrideWith(() => _FakeOwnerProducts(items)),
      ],
      child: const MaterialApp(home: OwnerProductsView()),
    );
  }

  testWidgets('shows counter and paused badge', (tester) async {
    await tester.pumpWidget(
      buildView(
        items: <ProductModel>[
          product(id: 'p1', active: true),
          product(id: 'p2', active: false),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 / 30'), findsOneWidget);
    expect(find.text('Producto p1'), findsOneWidget);
    expect(find.text('Producto p2'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
  });

  testWidgets('empty list shows empty state', (tester) async {
    await tester.pumpWidget(buildView(items: <ProductModel>[]));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no cargaste productos'), findsOneWidget);
    expect(find.text('Subir el primero'), findsOneWidget);
  });
}
