import 'dart:async';

import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _app(GoRouter router) => MaterialApp.router(routerConfig: router);

GoRouter _router() {
  return GoRouter(
    initialLocation: '/a',
    routes: <RouteBase>[
      GoRoute(
        path: '/a',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Center(child: Text('A'))),
      ),
      GoRoute(
        path: '/b',
        builder: (BuildContext context, GoRouterState state) => const Scaffold(
          appBar: _BackAppBar(),
          body: Center(child: Text('B')),
        ),
      ),
    ],
  );
}

class _BackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _BackAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(leading: const AppBackButton(fallback: '/a'));
  }
}

void main() {
  testWidgets('pops when there is history', (WidgetTester tester) async {
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router));
    unawaited(router.push('/b'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('goes to fallback without history', (WidgetTester tester) async {
    final GoRouter router = _router();
    await tester.pumpWidget(_app(router));
    // Deep link straight into /b (no stack).
    router.go('/b');
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
  });
}
