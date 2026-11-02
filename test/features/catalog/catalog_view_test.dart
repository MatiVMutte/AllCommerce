import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/core/widgets/price_pill.dart';
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
    isClaimed: true,
    createdAt: DateTime(2025),
  );

  final List<ProductModel> products = <ProductModel>[
    ProductModel(
      id: 'p1',
      tenantId: 't1',
      title: 'Vaso térmico',
      category: 'home',
      price: 100,
      compareAtPrice: 125,
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

  /// One product per add-flow kind: plain, variants and fractional unit.
  final List<ProductModel> quickAddProducts = <ProductModel>[
    ProductModel(
      id: 'p1',
      tenantId: 't1',
      title: 'Pan lactal',
      category: 'food',
      price: 100,
      isActive: true,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
    ProductModel(
      id: 'p2',
      tenantId: 't1',
      title: 'Remera',
      category: 'clothing',
      price: 200,
      variants: <String>['Rojo', 'Azul'],
      isActive: true,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
    ProductModel(
      id: 'p3',
      tenantId: 't1',
      title: 'Queso',
      category: 'food',
      price: 1000,
      unit: 'kg',
      isActive: true,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    ),
  ];

  Widget buildView({bool tenantExists = true, List<ProductModel>? items}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tenantBySlugProvider('demo')
            .overrideWith((Ref ref) async => tenantExists ? tenant : null),
        catalogProductsProvider('t1')
            .overrideWith((Ref ref) async => items ?? products),
      ],
      child: const MaterialApp(home: CatalogView(slug: 'demo')),
    );
  }

  dynamic readCart(WidgetTester tester) {
    return ProviderScope.containerOf(tester.element(find.byType(CatalogView)))
        .read(cartProvider);
  }

  /// The default 800×600 surface leaves product cards below the fold, so a
  /// tap on their (+) lands off-screen. A taller surface renders them.
  void tallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('renders product titles and filters by search', (tester) async {
    await tester.pumpWidget(buildView());
    await tester.pumpAndSettle();

    expect(find.text('Vaso térmico'), findsOneWidget);
    expect(find.text('Remera lisa'), findsOneWidget);
    expect(find.byType(PricePill), findsNWidgets(2));
    expect(find.text('\$100'), findsOneWidget);
    expect(find.text('\$125'), findsOneWidget);
    expect(find.text('-20% OFF'), findsOneWidget);
    expect(find.text('Ofertas'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNWidgets(2));

    await tester.tap(find.text('Ofertas'));
    await tester.pumpAndSettle();
    expect(find.text('Vaso térmico'), findsOneWidget);
    expect(find.text('Remera lisa'), findsNothing);

    await tester.tap(find.text('Ofertas'));
    await tester.pumpAndSettle();

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

  testWidgets('+ on a plain product adds it straight to the cart', (
    tester,
  ) async {
    tallSurface(tester);
    await tester.pumpWidget(buildView(items: quickAddProducts));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).at(0)); // Pan lactal
    await tester.pumpAndSettle();

    expect(find.text('Cantidad'), findsNothing); // no sheet opened
    final cart = readCart(tester);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.productId, 'p1');
    expect(cart.items.single.quantity, 1);
  });

  testWidgets('+ on a variant product opens quick-add, not the product page', (
    tester,
  ) async {
    tallSurface(tester);
    await tester.pumpWidget(buildView(items: quickAddProducts));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).at(1)); // Remera
    await tester.pumpAndSettle();

    // The sheet asks for a variant; the button stays disabled meanwhile.
    expect(find.text('Elegí una opción'), findsWidgets);

    await tester.tap(find.text('Rojo'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Agregar'));
    await tester.pumpAndSettle();

    final cart = readCart(tester);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.productId, 'p2');
    expect(cart.items.single.variant, 'Rojo');
    expect(cart.items.single.quantity, 1);
  });

  testWidgets('+ on a fractional product opens quick-add with 0.25 step', (
    tester,
  ) async {
    tallSurface(tester);
    await tester.pumpWidget(buildView(items: quickAddProducts));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).at(2)); // Queso
    await tester.pumpAndSettle();

    expect(find.text('Cantidad'), findsOneWidget);

    await tester.tap(find.textContaining('Agregar'));
    await tester.pumpAndSettle();

    final cart = readCart(tester);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.productId, 'p3');
    expect(cart.items.single.quantity, 0.25);
  });
}
