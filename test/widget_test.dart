import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/catalog/presentation/views/store_directory_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('store directory shows active tenant', (tester) async {
    final TenantModel tenantDemo = TenantModel(
      id: 't1',
      slug: 'demo',
      name: 'Demo Store',
      whatsapp: '5491100000000',
      primaryColor: '#0052FF',
      plan: PlanType.trial,
      trialStartedAt: DateTime(2025),
      planExpiresAt: DateTime.now().add(const Duration(days: 10)),
      isActive: true,
      isClaimed: true,
      createdAt: DateTime(2025),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeTenantsProvider(null).overrideWith((_) async => <TenantModel>[tenantDemo]),
        ],
        child: const MaterialApp(home: StoreDirectoryView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo Store'), findsOneWidget);
  });
}
