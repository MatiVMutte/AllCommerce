import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildBar({
    int selectedIndex = 0,
    int cartBadge = 0,
    VoidCallback? onCenterTap,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        bottomNavigationBar: FloatingNavBar(
          centerIcon: Icons.shopping_cart_rounded,
          centerBadgeCount: cartBadge,
          onCenterTap: onCenterTap,
          items: <FloatingNavItem>[
            FloatingNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Inicio',
              selected: selectedIndex == 0,
              onTap: () {},
            ),
            FloatingNavItem(
              icon: Icons.search_outlined,
              activeIcon: Icons.search_rounded,
              label: 'Buscar',
              selected: selectedIndex == 1,
              onTap: () {},
            ),
            FloatingNavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Pedidos',
              selected: selectedIndex == 2,
              onTap: () {},
            ),
            FloatingNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Perfil',
              selected: selectedIndex == 3,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('active item uses the filled icon', (tester) async {
    await tester.pumpWidget(buildBar(selectedIndex: 2));
    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('center button shows cart badge', (tester) async {
    await tester.pumpWidget(buildBar(cartBadge: 3));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('center tap fires the callback', (tester) async {
    int taps = 0;
    await tester.pumpWidget(buildBar(onCenterTap: () => taps++));
    await tester.tap(find.byIcon(Icons.shopping_cart_rounded));
    expect(taps, 1);
  });
}
