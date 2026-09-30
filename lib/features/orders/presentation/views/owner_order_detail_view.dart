import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/order_status_chip.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/services/whatsapp_message_builder.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      final bool? confirm = await showAppConfirmSheet(
        context,
        title: '¿Rechazar el pedido #${order.orderNumber}?',
        message: 'El cliente no va a poder seguir con este pedido.',
        confirmLabel: 'Rechazar',
        destructive: true,
      );
      if (confirm != true) return;
    }
    if (!mounted) return;
    final OrderModel? updated = await ref
        .read(ownerOrdersControllerProvider.notifier)
        .changeStatus(order, next);
    if (!mounted) return;
    if (updated != null) {
      AppHaptics.success();
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
    final AppTokens tokens = context.tokens;
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
          leading: const AppBackButton(fallback: '/owner/orders'),
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
    final List<OrderStatus> forward = order.status.nextOptions
        .where((OrderStatus s) => s != OrderStatus.rejected)
        .toList();
    final bool canReject =
        order.status.nextOptions.contains(OrderStatus.rejected);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/owner/orders'),
        title: Row(
          children: <Widget>[
            Text('Pedido #${order.orderNumber}'),
            const SizedBox(width: 10),
            OrderStatusChip(status: order.status),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                Formatters.dateTime(order.createdAt),
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                ),
              ),
              const SizedBox(height: 20),
              const _Section('CLIENTE'),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: tokens.surfaceMuted,
                    child: Text(
                      order.customerNameSnapshot.characters.first
                          .toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          order.customerNameSnapshot,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          order.customerPhoneSnapshot,
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              tenantAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (Object e, StackTrace s) =>
                    const SizedBox.shrink(),
                data: (TenantModel? tenant) => tenant == null
                    ? const SizedBox.shrink()
                    : SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                          ),
                          label:
                              const Text('Escribir por WhatsApp'),
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
              ),
              const SizedBox(height: 24),
              const _Section('ÍTEMS'),
              const SizedBox(height: 8),
              itemsAsync.when(
                loading: () => const AppSkeleton(height: 80),
                error: (Object e, StackTrace s) =>
                    const Text('No se pudieron cargar los items.'),
                data: (List<OrderItemModel> items) => Column(
                  children: <Widget>[
                    for (final OrderItemModel item in items)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surfaceMuted,
                                borderRadius:
                                    BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${item.quantity}×',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.titleSnapshot,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: tokens.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    Formatters.price(
                                      item.unitPrice,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Formatters.price(item.lineTotal),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _Section('RESUMEN'),
              const SizedBox(height: 8),
              _SummaryRow(
                label: 'Subtotal',
                value: Formatters.price(order.subtotal),
              ),
              if (order.discount > 0)
                _SummaryRow(
                  label: 'Descuento',
                  value:
                      '-${Formatters.price(order.discount)}',
                ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.price(order.total),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              if (order.notes != null &&
                  order.notes!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                const _Section('NOTAS'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    order.notes!,
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                ),
              ],
              if (order.status.isFinal)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      order.status == OrderStatus.delivered
                          ? 'Pedido entregado'
                          : 'Pedido rechazado',
                      style:
                          TextStyle(color: tokens.textSecondary),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: order.status.isFinal
          ? null
          : SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  border: Border(
                    top: BorderSide(color: tokens.border),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int i = 0; i < forward.length; i++)
                      i == 0
                          ? FilledButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                      _changeStatus(forward[i]),
                              child: Text(
                                'Marcar '
                                '${forward[i].label.toLowerCase()}',
                              ),
                            )
                          : TextButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                      _changeStatus(forward[i]),
                              child: Text(
                                'Marcar '
                                '${forward[i].label.toLowerCase()}',
                              ),
                            ),
                    if (canReject)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () =>
                                _changeStatus(OrderStatus.rejected),
                        child: Text(
                          'Rechazar pedido',
                          style: TextStyle(color: tokens.danger),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: context.tokens.textTertiary,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
