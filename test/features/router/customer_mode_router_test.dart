import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/router/app_router.dart';
import 'package:all_commerce/core/router/customer_mode.dart';
import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/billing/data/repositories/ai_usage_repository.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/views/store_directory_view.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/models/sales_metrics.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:all_commerce/features/store/presentation/views/owner_home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _EmptyOwnerProducts extends OwnerProductsNotifier {
  _EmptyOwnerProducts() : super('t1');

  @override
  Future<List<ProductModel>> build() async => <ProductModel>[];
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

  final Session session = Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: const User(
      id: 'u1',
      appMetadata: <String, dynamic>{},
      userMetadata: <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2025-01-01T00:00:00Z',
    ),
  );

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(
          SupabaseClient(
            'https://test.supabase.co',
            'anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionProvider.overrideWith((Ref ref) => session),
        currentProfileProvider.overrideWith((Ref ref) async => owner),
        tenantByIdProvider('t1').overrideWith((Ref ref) async => tenant),
        ownerProductsProvider('t1').overrideWith(() => _EmptyOwnerProducts()),
        ownerOrdersProvider('t1')
            .overrideWith((Ref ref) async => const <OrderModel>[]),
        ownerSalesMetricsProvider('t1').overrideWith(
          (Ref ref) async => const SalesMetrics(
            monthTotal: 0,
            monthCount: 0,
            prevTotal: 0,
            prevCount: 0,
            topProducts: <SalesTopProduct>[],
          ),
        ),
        aiUsageProvider.overrideWith((Ref ref) async => const AiUsage(used: 0)),
        activeTenantsProvider(null)
            .overrideWith((Ref ref) async => <TenantModel>[tenant]),
        publicZonesProvider.overrideWith((Ref ref) async => const <String>[]),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(routerProvider)),
        ),
      ),
    );
    return container;
  }

  testWidgets('owner can switch to customer directory and back', (
    tester,
  ) async {
    final ProviderContainer container = await pumpApp(tester);
    await tester.pumpAndSettle();

    // Owner lands on the panel by default.
    expect(find.byType(OwnerHomeView), findsOneWidget);

    // Tap "Explorar locales" -> customer mode at '/'.
    await tester.tap(find.byIcon(Icons.travel_explore_rounded));
    await tester.pump();
    expect(container.read(customerModeProvider), isTrue);
    await tester.pumpAndSettle();

    expect(find.byType(StoreDirectoryView), findsOneWidget);

    // "Mi negocio" takes the owner back to '/owner'.
    await tester.tap(find.text('Mi negocio'));
    await tester.pump();
    expect(container.read(customerModeProvider), isFalse);
    await tester.pumpAndSettle();

    expect(find.byType(OwnerHomeView), findsOneWidget);
  });
}
