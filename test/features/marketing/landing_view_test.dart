import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:all_commerce/features/billing/data/models/plan_model.dart';
import 'package:all_commerce/features/billing/data/repositories/plan_repository.dart';
import 'package:all_commerce/features/marketing/presentation/views/landing_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const List<PlanModel> _plans = <PlanModel>[
  PlanModel(
    id: PlanType.free,
    name: 'Gratis',
    maxProducts: 5,
    priceArs: 0,
    sortOrder: 0,
    highlights: <String>['Hasta 5 productos'],
  ),
  PlanModel(
    id: PlanType.trial,
    name: 'Prueba',
    maxProducts: 30,
    priceArs: 0,
    sortOrder: 0,
    highlights: <String>['14 días gratis'],
  ),
  PlanModel(
    id: PlanType.crecimiento,
    name: 'Crecimiento',
    maxProducts: 150,
    priceArs: 19900,
    sortOrder: 2,
    highlights: <String>['Hasta 150 productos'],
  ),
];

Future<void> _pump(WidgetTester tester, Size size, ThemeData theme) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [plansProvider.overrideWith((_) async => _plans)],
      child: MaterialApp(theme: theme, home: const LandingView()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final (String name, Size size) in <(String, Size)>[
    ('desktop', const Size(1280, 900)),
    ('mobile', const Size(360, 780)),
  ]) {
    testWidgets('landing renders without layout errors on $name', (
      tester,
    ) async {
      await _pump(tester, size, AppTheme.light());
      expect(tester.takeException(), isNull);
      expect(find.text('Crear mi local gratis'), findsWidgets);

      // Scroll through the whole page so every section lays out.
      final Finder scrollable = find.byType(Scrollable).first;
      for (int i = 0; i < 12; i++) {
        await tester.drag(scrollable, const Offset(0, -700));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Preguntas frecuentes'), findsOneWidget);
      // Trial plan is hidden; free + paid plans are listed.
      expect(find.text('Prueba'), findsNothing);
      expect(find.text('Crecimiento'), findsOneWidget);
    });
  }

  testWidgets('landing renders in dark mode', (tester) async {
    await _pump(tester, const Size(1280, 900), AppTheme.dark());
    expect(tester.takeException(), isNull);
  });
}
