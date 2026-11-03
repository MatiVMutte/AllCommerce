import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bottom-bar shell for the owner side:
/// [Panel] [Productos] (● IA) [Pedidos] [Local]
class OwnerShell extends ConsumerWidget {
  const OwnerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;
    final List<OrderModel>? orders = tenantId == null
        ? null
        : ref.watch(ownerOrdersProvider(tenantId)).value;
    final int pending = orders == null
        ? 0
        : pendingCount(orders.where((OrderModel o) => !o.isArchived).toList());

    return AdaptiveNavShell(
      centerIcon: Icons.auto_awesome,
      centerTooltip: 'Asistente IA',
      onCenterTap: () => _goBranch(4),
      items: <FloatingNavItem>[
        FloatingNavItem(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          label: 'Panel',
          selected: navigationShell.currentIndex == 0,
          onTap: () => _goBranch(0),
        ),
        FloatingNavItem(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2_rounded,
          label: 'Productos',
          badgeCount: 0,
          selected: navigationShell.currentIndex == 1,
          onTap: () => _goBranch(1),
        ),
        FloatingNavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long_rounded,
          label: 'Pedidos',
          badgeCount: pending,
          selected: navigationShell.currentIndex == 2,
          onTap: () => _goBranch(2),
        ),
        FloatingNavItem(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront_rounded,
          label: 'Local',
          selected: navigationShell.currentIndex == 3,
          onTap: () => _goBranch(3),
        ),
      ],
      child: navigationShell,
    );
  }
}
