import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/features/catalog/presentation/views/catalog_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

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
    createdAt: DateTime(2025),
  );

  final List<ProductModel> products = <ProductModel>[
    ProductModel(
      id: 'p1',
      tenantId: 't1',
      title: 'Vaso térmico',
      category: 'home',
      price: 100,
      isActive: true,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
    ProductModel(
      id: 'p2',
      tenantId: 't1',
      title: 'Remera lisa',
      category: 'clothing',
      price: 200,
      isActive: true,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
  ];

  Widget buildView({bool tenantExists = true}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tenantBySlugProvider('demo').overrideWith(
          (Ref ref) async => tenantExists ? tenant : null,
        ),
        catalogProductsProvider('t1')
            .overrideWith((Ref ref) async => products),
      ],
      child: const MaterialApp(home: CatalogView(slug: 'demo')),
    );
  }

  testWidgets('renders product titles and filters by search', (tester) async {
    await tester.pumpWidget(buildView());
    await tester.pumpAndSettle();

    expect(find.text('Vaso térmico'), findsOneWidget);
    expect(find.text('Remera lisa'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'vaso');
    await tester.pumpAndSettle();

    expect(find.text('Vaso térmico'), findsOneWidget);
    expect(find.text('Remera lisa'), findsNothing);
  });

  testWidgets('unknown slug shows store not found', (tester) async {
    await tester.pumpWidget(buildView(tenantExists: false));
    await tester.pumpAndSettle();
    expect(find.text('Local no encontrado'), findsOneWidget);
  });
}
