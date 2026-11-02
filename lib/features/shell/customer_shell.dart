import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bottom-bar shell for the public/customer side:
/// [Inicio] [Buscar] (● Carrito) [Pedidos] [Perfil]
class CustomerShell extends ConsumerWidget {
  const CustomerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _openCart(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider);
    final String? slug = cart.tenantSlug;
    if (cart.isEmpty || slug == null) {
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        builder: (BuildContext context) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            32 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 16),
              const Text(
                'Tu carrito está vacío',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/');
                  },
                  child: const Text('Ver locales'),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    context.push('/s/$slug/cart');
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Re-tocar la pestaña actual vuelve a su raíz (como Instagram).
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int cartCount = ref.watch(cartProvider).itemCount.ceil();
    return AdaptiveNavShell(
      centerIcon: Icons.shopping_cart_rounded,
      centerBadgeCount: cartCount,
      centerTooltip: 'Tu carrito',
      onCenterTap: () => _openCart(context, ref),
      items: <FloatingNavItem>[
        FloatingNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Inicio',
          selected: navigationShell.currentIndex == 0,
          onTap: () => _goBranch(0),
        ),
        FloatingNavItem(
          icon: Icons.local_offer_outlined,
          activeIcon: Icons.local_offer_rounded,
          label: 'Ofertas',
          selected: navigationShell.currentIndex == 1,
          onTap: () => _goBranch(1),
        ),
        FloatingNavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long_rounded,
          label: 'Pedidos',
          selected: navigationShell.currentIndex == 2,
          onTap: () => _goBranch(2),
        ),
        FloatingNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Perfil',
          selected: navigationShell.currentIndex == 3,
          onTap: () => _goBranch(3),
        ),
      ],
      child: navigationShell,
    );
  }
}
