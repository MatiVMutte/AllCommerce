import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/core/widgets/order_status_chip.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/order_grouping.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class OwnerOrdersView extends ConsumerStatefulWidget {
  const OwnerOrdersView({super.key});

  @override
  ConsumerState<OwnerOrdersView> createState() => _OwnerOrdersViewState();
}

class _OwnerOrdersViewState extends ConsumerState<OwnerOrdersView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;
    if (tenantId == null) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.storefront_outlined,
          title: 'No encontramos tu local',
        ),
      );
    }
    final AsyncValue<List<OrderModel>> ordersAsync = ref.watch(
      ownerOrdersProvider(tenantId),
    );
    final OrderStatus? statusFilter = ref.watch(ownerOrderStatusFilterProvider);
    final int pending = ordersAsync.value == null
        ? 0
        : pendingCount(ordersAsync.value!);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Pedidos',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (pending > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$pending nuevos',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre, teléfono o #número',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (String value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: <Widget>[
                      _StatusChip(
                        label: 'Todos',
                        selected: statusFilter == null,
                        onTap: () => ref
                            .read(ownerOrderStatusFilterProvider.notifier)
                            .select(null),
                      ),
                      for (final OrderStatus status in OrderStatus.values)
                        _StatusChip(
                          label: status.label,
                          selected: statusFilter == status,
                          onTap: () => ref
                              .read(ownerOrderStatusFilterProvider.notifier)
                              .select(status),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ordersAsync.when(
                    loading: () =>
                        const AppSkeletonList(itemCount: 6, itemHeight: 64),
                    error: (Object error, StackTrace stack) => AppErrorState(
                      onRetry: () =>
                          ref.invalidate(ownerOrdersProvider(tenantId)),
                    ),
                    data: (List<OrderModel> orders) {
                      final List<OrderModel> filtered = filterOrders(
                        orders,
                        status: statusFilter,
                        query: _query,
                      );
                      if (orders.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Todavía no recibiste pedidos',
                        );
                      }
                      if (filtered.isEmpty) {
                        return AppEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Sin resultados',
                          actionLabel: 'Limpiar filtros',
                          onAction: () {
                            setState(() => _query = '');
                            ref
                                .read(ownerOrderStatusFilterProvider.notifier)
                                .select(null);
                          },
                        );
                      }
                      final List<OrderDayGroup> groups = groupOrdersByDay(
                        filtered,
                      );
                      return RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(ownerOrdersProvider(tenantId)),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            FloatingNavBar.height,
                          ),
                          children: <Widget>[
                            for (final OrderDayGroup group
                                in groups) ...<Widget>[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 4,
                                ),
                                child: Text(
                                  group.label.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                    color: tokens.textTertiary,
                                  ),
                                ),
                              ),
                              for (
                                int i = 0;
                                i < group.orders.length;
                                i++
                              ) ...<Widget>[
                                _OrderRow(order: group.orders[i]),
                                if (i < group.orders.length - 1)
                                  Divider(height: 1, color: tokens.border),
                              ],
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? tokens.textPrimary : tokens.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Theme.of(context).scaffoldBackgroundColor
                  : tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends ConsumerWidget {
  const _OrderRow({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final List<OrderItemModel>? items = ref
        .watch(orderItemsProvider(order.id))
        .value;
    final String time = DateFormat('HH:mm').format(order.createdAt.toLocal());
    return InkWell(
      onTap: () => context.push('/owner/orders/${order.id}', extra: order),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        '#${order.orderNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.customerNameSnapshot,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items == null ? time : '${items.length} ítems · $time',
                    style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  Formatters.price(order.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                OrderStatusChip(status: order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
