import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/features/admin/data/models/admin_models.dart';
import 'package:all_commerce/features/admin/data/repositories/admin_repository.dart';
import 'package:all_commerce/features/admin/presentation/views/admin_home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  const AdminMetrics metrics = AdminMetrics(
    tenantsTotal: 3,
    tenantsPaying: 1,
    tenantsTrial: 1,
    tenantsFree: 1,
    tenantsExpired: 1,
    tenantsUnclaimed: 0,
    mrrArs: 19900,
    customersTotal: 9,
    ordersMonth: 4,
    ordersTotal: 30,
    aiMonth: 11,
  );

  List<AdminTenantRow> rows() => <AdminTenantRow>[
    AdminTenantRow(
      id: 't1',
      name: 'Tienda Norte',
      slug: 'norte',
      plan: PlanType.inicial,
      planExpiresAt: DateTime.now().add(const Duration(days: 20)),
      isActive: true,
      isClaimed: true,
      createdAt: DateTime(2025),
      ownerName: 'Ana',
      productCount: 4,
      orderCount: 2,
      aiUsedMonth: 1,
    ),
    AdminTenantRow(
      id: 't2',
      name: 'Tienda Sur',
      slug: 'sur',
      plan: PlanType.crecimiento,
      planExpiresAt: DateTime.now().subtract(const Duration(days: 2)),
      isActive: true,
      isClaimed: true,
      createdAt: DateTime(2025),
      ownerName: 'Beto',
      productCount: 8,
      orderCount: 5,
      aiUsedMonth: 0,
    ),
  ];

  Widget app() {
    return ProviderScope(
      overrides: [
        adminMetricsProvider.overrideWith((Ref ref) async => metrics),
        adminTenantsProvider.overrideWith((Ref ref) async => rows()),
      ],
      child: const MaterialApp(home: AdminHomeView()),
    );
  }

  testWidgets('shows metrics and tenant rows', (WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Locales pagando'), findsOneWidget);
    expect(find.text('Vencidos'), findsWidgets);
    expect(find.text('\$19.900'), findsOneWidget);
    expect(find.text('Tienda Norte'), findsOneWidget);
    expect(find.text('Tienda Sur'), findsOneWidget);
    expect(
      find.text('Clientes registrados 9 · Pedidos totales 30'),
      findsOneWidget,
    );
  });

  testWidgets('Vencidos chip filters the list', (WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Vencidos'));
    await tester.pumpAndSettle();

    expect(find.text('Tienda Sur'), findsOneWidget);
    expect(find.text('Tienda Norte'), findsNothing);
  });
}
