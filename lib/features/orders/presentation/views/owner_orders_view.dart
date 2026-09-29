import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OwnerOrdersView extends ConsumerStatefulWidget {
  const OwnerOrdersView({super.key});

  @override
  ConsumerState<OwnerOrdersView> createState() => _OwnerOrdersViewState();
}

class _OwnerOrdersViewState extends ConsumerState<OwnerOrdersView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;
    if (tenantId == null) {
      return const Scaffold(
        body: Center(child: Text('Ocurrió un error. Intentá de nuevo.')),
      );
    }
    final AsyncValue<List<OrderModel>> ordersAsync =
        ref.watch(ownerOrdersProvider(tenantId));
    final OrderStatus? statusFilter =
        ref.watch(ownerOrderStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        leading: BackButton(onPressed: () => context.go('/owner')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre, teléfono o #número',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (String value) =>
                      setState(() => _query = value),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Todos'),
                        selected: statusFilter == null,
                        onSelected: (_) => ref
                            .read(
                              ownerOrderStatusFilterProvider.notifier,
                            )
                            .select(null),
                      ),
                    ),
                    for (final OrderStatus status in OrderStatus.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status.label),
                          selected: statusFilter == status,
                          onSelected: (_) => ref
                              .read(
                                ownerOrderStatusFilterProvider.notifier,
                              )
                              .select(status),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ordersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (Object error, StackTrace stack) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'Ocurrió un error. Intentá de nuevo.',
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => ref.invalidate(
                            ownerOrdersProvider(tenantId),
                          ),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                  data: (List<OrderModel> orders) {
                    final List<OrderModel> filtered = filterOrders(
                      orders,
                      status: statusFilter,
                      query: _query,
                    );
                    if (orders.isEmpty) {
                      return const Center(
                        child: Text('Todavía no recibiste pedidos'),
                      );
                    }
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text('Sin resultados'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() => _query = '');
                                ref
                                    .read(
                                      ownerOrderStatusFilterProvider
                                          .notifier,
                                    )
                                    .select(null);
                              },
                              child: const Text('Limpiar filtros'),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(ownerOrdersProvider(tenantId)),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder:
                            (BuildContext context, int index) =>
                                _OrderTile(order: filtered[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        order.status.color(Theme.of(context).colorScheme);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.go('/owner/orders/${order.id}', extra: order),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '#${order.orderNumber} · '
                      '${order.customerNameSnapshot}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Formatters.dateTime(order.createdAt)} · '
                      '${Formatters.price(order.total)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(order.status.label),
                backgroundColor: statusColor.withValues(alpha: 0.15),
                labelStyle: TextStyle(color: statusColor),
                side: BorderSide.none,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
