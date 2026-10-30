import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bottom-bar shell for the public/customer side:
/// [Inicio] [Buscar] (● Carrito) [Pedidos] [Perfil]
class CustomerShell extends ConsumerWidget {
  const CustomerShell({required this.state, required this.child, super.key});

  final GoRouterState state;
  final Widget child;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String loc = state.matchedLocation;
    final int cartCount = ref.watch(cartProvider).itemCount;
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
          selected: loc == '/' || loc.startsWith('/s/'),
          onTap: () => context.go('/'),
        ),
        FloatingNavItem(
          icon: Icons.local_offer_outlined,
          activeIcon: Icons.local_offer_rounded,
          label: 'Ofertas',
          selected: loc.startsWith('/ofertas'),
          onTap: () => context.go('/ofertas'),
        ),
        FloatingNavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long_rounded,
          label: 'Pedidos',
          selected: loc.startsWith('/my-orders'),
          onTap: () => context.go('/my-orders'),
        ),
        FloatingNavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Perfil',
          selected: loc.startsWith('/profile'),
          onTap: () => context.go('/profile'),
        ),
      ],
      child: child,
    );
  }
}
