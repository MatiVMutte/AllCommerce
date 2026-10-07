import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/cart/presentation/views/cart_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  late SharedPreferences prefs;

  Widget buildView() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tenantBySlugProvider('demo').overrideWith(
          (Ref ref) async => tenant,
        ),
      ],
      child: const MaterialApp(home: CartView(slug: 'demo')),
    );
  }

  testWidgets('empty cart shows empty state', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildView());
    await tester.pumpAndSettle();

    expect(find.text('Tu carrito está vacío'), findsOneWidget);
    expect(find.text('Ver catálogo'), findsOneWidget);
  });

  testWidgets('cart with two items shows titles and subtotal',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cart_v1': '{"tenant_id":"t1","tenant_slug":"demo","items":['
          '{"product_id":"p1","title":"Vaso térmico","price":100,'
          '"image_url":null,"quantity":1},'
          '{"product_id":"p2","title":"Remera","price":200,'
          '"image_url":null,"quantity":2}'
          ']}',
    });
    prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildView());
    await tester.pumpAndSettle();

    expect(find.text('Vaso térmico'), findsOneWidget);
    expect(find.text('Remera'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('\$500'), findsNWidgets(2));
  });
}
