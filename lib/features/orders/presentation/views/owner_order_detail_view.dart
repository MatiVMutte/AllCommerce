import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/services/whatsapp_message_builder.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class OwnerOrderDetailView extends ConsumerStatefulWidget {
  const OwnerOrderDetailView({
    required this.orderId,
    this.order,
    super.key,
  });

  final String orderId;
  final OrderModel? order;

  @override
  ConsumerState<OwnerOrderDetailView> createState() =>
      _OwnerOrderDetailViewState();
}

class _OwnerOrderDetailViewState
    extends ConsumerState<OwnerOrderDetailView> {
  OrderModel? _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _changeStatus(OrderStatus next) async {
    final OrderModel order = _order!;
    if (next == OrderStatus.rejected) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('¿Rechazar el pedido #${order.orderNumber}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    if (!mounted) return;
    final OrderModel? updated = await ref
        .read(ownerOrdersControllerProvider.notifier)
        .changeStatus(order, next);
    if (!mounted) return;
    if (updated != null) {
      setState(() => _order = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido marcado como ${next.label}'),
        ),
      );
    } else {
      showErrorSnackBar(
        context,
        ref.read(ownerOrdersControllerProvider).error ??
            Exception('unknown'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;

    OrderModel? resolved = _order;
    if (resolved == null && tenantId != null) {
      final List<OrderModel>? orders =
          ref.watch(ownerOrdersProvider(tenantId)).value;
      for (final OrderModel o in orders ?? <OrderModel>[]) {
        if (o.id == widget.orderId) {
          resolved = o;
          _order = o;
          break;
        }
      }
    }

    if (resolved == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pedido'),
          leading: BackButton(
            onPressed: () => context.go('/owner/orders'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final OrderModel order = resolved;

    final AsyncValue<TenantModel?> tenantAsync = tenantId == null
        ? const AsyncValue<TenantModel?>.data(null)
        : ref.watch(tenantByIdProvider(tenantId));
    final AsyncValue<List<OrderItemModel>> itemsAsync =
        ref.watch(orderItemsProvider(order.id));
    final bool busy =
        ref.watch(ownerOrdersControllerProvider).busyOrderId ==
            order.id;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #${order.orderNumber}'),
        leading: BackButton(
          onPressed: () => context.go('/owner/orders'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        order.customerNameSnapshot,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Tel: ${order.customerPhoneSnapshot}'),
                      const SizedBox(height: 12),
                      tenantAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (Object e, StackTrace s) =>
                            const SizedBox.shrink(),
                        data: (TenantModel? tenant) => tenant == null
                            ? const SizedBox.shrink()
                            : FilledButton.tonalIcon(
                                icon: const Icon(Icons.chat_outlined),
                                label: const Text(
                                  'Escribir por WhatsApp',
                                ),
                                onPressed: () => launchUrl(
                                  buildWhatsAppUri(
                                    order.customerPhoneSnapshot,
                                    'Hola ${order.customerNameSnapshot}! '
                                    'Te escribo de ${tenant.name} por tu '
                                    'pedido #${order.orderNumber}.',
                                  ),
                                  mode: LaunchMode.externalApplication,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: itemsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (Object e, StackTrace s) =>
                        const Text('No se pudieron cargar los items.'),
                    data: (List<OrderItemModel> items) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final OrderItemModel item in items)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '${item.quantity} x '
                                    '${item.titleSnapshot}',
                                  ),
                                ),
                                Text(Formatters.price(item.lineTotal)),
                              ],
                            ),
                          ),
                        const Divider(height: 24),
                        Row(
                          children: <Widget>[
                            const Expanded(child: Text('Subtotal')),
                            Text(Formatters.price(order.subtotal)),
                          ],
                        ),
                        if (order.discount > 0)
                          Row(
                            children: <Widget>[
                              const Expanded(child: Text('Descuento')),
                              Text(
                                '-${Formatters.price(order.discount)}',
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                'Total',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              Formatters.price(order.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (order.notes != null &&
                            order.notes!.trim().isNotEmpty) ...<Widget>[
                          const Divider(height: 24),
                          Text('Notas: ${order.notes}'),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Chip(
                            label: Text(order.status.label),
                            backgroundColor: order.status
                                .color(scheme)
                                .withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: order.status.color(scheme),
                            ),
                            side: BorderSide.none,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.dateTime(order.createdAt),
                            style:
                                Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (order.status.isFinal)
                        const Text('Este pedido está cerrado')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final OrderStatus next
                                in order.status.nextOptions)
                              if (next == OrderStatus.rejected)
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: scheme.error,
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () => _changeStatus(next),
                                  child: Text(next.label),
                                )
                              else
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _changeStatus(next),
                                  child: Text(next.label),
                                ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
