import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bottom-bar shell for the owner side:
/// [Panel] [Productos] (● Subir) [Pedidos] [Local]
class OwnerShell extends ConsumerStatefulWidget {
  const OwnerShell({required this.state, required this.child, super.key});

  final GoRouterState state;
  final Widget child;

  @override
  ConsumerState<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends ConsumerState<OwnerShell> {
  bool _visible = true;

  void _upload(TenantModel? tenant) {
    if (tenant == null || !tenant.canPublish) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Llegaste al límite de tu plan'),
        ),
      );
      return;
    }
    context.push('/owner/products/new');
  }

  @override
  Widget build(BuildContext context) {
    final String loc = widget.state.matchedLocation;
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;
    final TenantModel? tenant = tenantId == null
        ? null
        : ref.watch(tenantByIdProvider(tenantId)).value;
    final List<OrderModel>? orders = tenantId == null
        ? null
        : ref.watch(ownerOrdersProvider(tenantId)).value;
    final int pending = orders == null ? 0 : pendingCount(orders);

    return NotificationListener<UserScrollNotification>(
      onNotification: (UserScrollNotification n) {
        final bool forward =
            n.direction == ScrollDirection.forward;
        if (n.direction == ScrollDirection.idle) return false;
        if (forward != _visible) setState(() => _visible = forward);
        return false;
      },
      child: Scaffold(
        extendBody: true,
        body: widget.child,
        bottomNavigationBar: FloatingNavBar(
          visible: _visible,
          centerIcon: Icons.add_a_photo_outlined,
          onCenterTap: () => _upload(tenant),
          items: <FloatingNavItem>[
            FloatingNavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Panel',
              selected: loc == '/owner',
              onTap: () => context.go('/owner'),
            ),
            FloatingNavItem(
              icon: Icons.inventory_2_outlined,
              activeIcon: Icons.inventory_2_rounded,
              label: 'Productos',
              badgeCount: 0,
              selected: loc.startsWith('/owner/products'),
              onTap: () => context.go('/owner/products'),
            ),
            FloatingNavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Pedidos',
              badgeCount: pending,
              selected: loc.startsWith('/owner/orders'),
              onTap: () => context.go('/owner/orders'),
            ),
            FloatingNavItem(
              icon: Icons.storefront_outlined,
              activeIcon: Icons.storefront_rounded,
              label: 'Local',
              selected: loc.startsWith('/owner/settings'),
              onTap: () => context.go('/owner/settings'),
            ),
          ],
        ),
      ),
    );
  }
}
