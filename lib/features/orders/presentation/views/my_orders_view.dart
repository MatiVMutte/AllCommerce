import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/order_status_chip.dart';
import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/services/whatsapp_message_builder.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class MyOrdersView extends ConsumerWidget {
  const MyOrdersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OrderModel>> ordersAsync =
        ref.watch(myOrdersProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/'),
        title: const Text('Mis pedidos'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ordersAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace s) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Ocurrió un error. Intentá de nuevo.'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(myOrdersProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
            data: (List<OrderModel> orders) {
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Todavía no hiciste pedidos'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Ver locales'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) =>
                    _MyOrderTile(order: orders[index]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MyOrderTile extends ConsumerWidget {
  const _MyOrderTile({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TenantModel?> tenantAsync =
        ref.watch(tenantByIdProvider(order.tenantId));
    final String tenantName = tenantAsync.value?.name ?? 'Local';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          '#${order.orderNumber} · $tenantName',
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${Formatters.dateTime(order.createdAt)} · '
          '${Formatters.price(order.total)}',
        ),
        trailing: OrderStatusChip(status: order.status),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          ref.watch(orderItemsProvider(order.id)).when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object e, StackTrace s) =>
                const Text('No se pudieron cargar los items.'),
            data: (List<OrderItemModel> items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final OrderItemModel item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${item.quantity} x ${item.titleSnapshot}',
                          ),
                        ),
                        Text(Formatters.price(item.lineTotal)),
                      ],
                    ),
                  ),
                const Divider(height: 16),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      Formatters.price(order.total),
                      style:
                          const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (tenantAsync.value != null)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Escribir al local por WhatsApp'),
              onPressed: () => launchUrl(
                buildWhatsAppUri(
                  tenantAsync.value!.whatsapp,
                  'Hola ${tenantAsync.value!.name}! '
                  'Te escribo por mi pedido #${order.orderNumber}.',
                ),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    );
  }
}
