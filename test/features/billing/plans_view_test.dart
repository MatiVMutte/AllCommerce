import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/billing/data/models/plan_model.dart';
import 'package:all_commerce/features/billing/data/repositories/plan_repository.dart';
import 'package:all_commerce/features/billing/presentation/views/plans_view.dart';
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
    plan: PlanType.inicial,
    trialStartedAt: DateTime(2025),
    planExpiresAt: DateTime.now().add(const Duration(days: 200)),
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

  final List<PlanModel> plans = <PlanModel>[
    const PlanModel(
      id: PlanType.trial,
      name: 'Prueba',
      maxProducts: 30,
      priceArs: 0,
      aiAnalysesPerMonth: 30,
      sortOrder: 0,
      highlights: <String>['14 días gratis'],
    ),
    const PlanModel(
      id: PlanType.inicial,
      name: 'Inicial',
      maxProducts: 30,
      priceArs: 9900,
      aiAnalysesPerMonth: 60,
      sortOrder: 1,
      highlights: <String>['Hasta 30 productos'],
    ),
    const PlanModel(
      id: PlanType.crecimiento,
      name: 'Crecimiento',
      maxProducts: 150,
      priceArs: 19900,
      aiAnalysesPerMonth: 300,
      sortOrder: 2,
      highlights: <String>['Hasta 150 productos'],
    ),
    const PlanModel(
      id: PlanType.pro,
      name: 'Pro',
      maxProducts: 1000,
      priceArs: 39900,
      sortOrder: 3,
      highlights: <String>['Todo ilimitado'],
    ),
  ];

  testWidgets('current plan card marked, others show CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plansProvider.overrideWith((Ref ref) async => plans),
          currentProfileProvider.overrideWith((Ref ref) async => owner),
          tenantByIdProvider('t1').overrideWith((Ref ref) async => tenant),
        ],
        child: const MaterialApp(home: PlansView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu plan actual'), findsOneWidget);
    expect(find.text('Plan actual'), findsOneWidget);
    expect(find.text('Quiero este plan'), findsNWidgets(2));
    expect(find.text('Más elegido'), findsOneWidget);
    expect(find.text('Prueba'), findsNothing); // trial hidden
    expect(find.text('\$9.900'), findsOneWidget);
  });
}
