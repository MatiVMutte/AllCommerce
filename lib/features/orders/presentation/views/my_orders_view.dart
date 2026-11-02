import 'dart:async';

import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/app_avatar.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_refresh_button.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/features/cart/data/models/cart_state.dart';
import 'package:all_commerce/features/orders/presentation/widgets/order_discount_rows.dart';
import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
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
    final AsyncValue<List<OrderModel>> ordersAsync = ref.watch(
      myOrdersProvider,
    );
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/'),
        title: const Text('Mis pedidos'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppRefreshButton(
              onRefresh: () async {
                ref.invalidate(myOrdersProvider);
                await ref
                    .read(myOrdersProvider.future)
                    .catchError((Object _) => const <OrderModel>[]);
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ordersAsync.when(
            loading: () => const AppSkeletonList(itemCount: 4, itemHeight: 88),
            error: (Object e, StackTrace s) =>
                AppErrorState(onRetry: () => ref.invalidate(myOrdersProvider)),
            data: (List<OrderModel> orders) {
              if (orders.isEmpty) {
                return AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Todavía no hiciste pedidos',
                  actionLabel: 'Ver locales',
                  onAction: () => context.go('/'),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(myOrdersProvider),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    AdaptiveNavShell.isWide(context)
                        ? 24
                        : FloatingNavBar.height,
                  ),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) =>
                      _MyOrderTile(order: orders[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Story-style segmented progress: one filled segment per step reached.
/// Rejected orders get a single red segment instead.
class _OrderProgress extends StatelessWidget {
  const _OrderProgress({required this.status});

  final OrderStatus status;

  static const List<OrderStatus> _steps = <OrderStatus>[
    OrderStatus.requested,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color active = status.color(scheme);
    if (status == OrderStatus.rejected) {
      return Row(
        children: <Widget>[
          Expanded(child: _Segment(color: active)),
          const SizedBox(width: 8),
          Icon(Icons.cancel_outlined, color: active, size: 18),
        ],
      );
    }
    final int current = _steps.indexOf(status).clamp(0, _steps.length - 1);
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < _steps.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _Segment(
                  color: i <= current ? active : tokens.surfaceMuted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (int i = 0; i < _steps.length; i++)
              Text(
                _steps[i].label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                  color: i == current ? active : tokens.textTertiary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _MyOrderTile extends ConsumerStatefulWidget {
  const _MyOrderTile({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_MyOrderTile> createState() => _MyOrderTileState();
}

/// Re-adds [order]'s items to the cart (skipping products that no
/// longer exist or ran out) and sends the user to checkout.
Future<void> _reorder(
  BuildContext context,
  WidgetRef ref,
  TenantModel tenant,
  OrderModel order,
) async {
  try {
    final List<OrderItemModel> items = await ref.read(
      orderItemsProvider(order.id).future,
    );
    final List<ProductModel> products = await ref.read(
      catalogProductsProvider(tenant.id).future,
    );
    final Map<String, ProductModel> byId = <String, ProductModel>{
      for (final ProductModel p in products) p.id: p,
    };
    if (!context.mounted) return;

    final CartController cart = ref.read(cartProvider.notifier);
    final CartState cartState = ref.read(cartProvider);
    if (cartState.tenantId != null &&
        cartState.tenantId != tenant.id &&
        cartState.items.isNotEmpty) {
      final bool? ok = await showAppConfirmSheet(
        context,
        title: 'Carrito de otro local',
        message:
            'Tu carrito tiene productos de otro local. '
            '¿Vaciarlo y repetir este pedido?',
        confirmLabel: 'Vaciar y pedir',
      );
      if (ok != true) return;
      cart.clear();
    }

    int added = 0;
    int skipped = 0;
    for (final OrderItemModel item in items) {
      final ProductModel? p = item.productId == null
          ? null
          : byId[item.productId];
      if (p == null || !p.isActive || p.isOutOfStock) {
        skipped++;
        continue;
      }
      double qty = item.quantity;
      if (p.trackStock && qty > p.stock) qty = p.stock;
      cart.add(p, tenant, quantity: qty, variant: item.variant);
      added++;
    }
    if (!context.mounted) return;
    if (added == 0) {
      showAppSnackBar(
        context,
        'Ningún producto de ese pedido sigue disponible',
        isError: true,
      );
      return;
    }
    if (skipped > 0) {
      showAppSnackBar(context, '$skipped producto(s) ya no están disponibles');
    }
    unawaited(context.push('/s/${tenant.slug}/cart'));
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'No se pudo repetir el pedido', isError: true);
    }
  }
}

class _MyOrderTileState extends ConsumerState<_MyOrderTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final OrderModel order = widget.order;
    final AsyncValue<TenantModel?> tenantAsync = ref.watch(
      tenantByIdProvider(order.tenantId),
    );
    final TenantModel? tenant = tenantAsync.value;
    final String tenantName = tenant?.name ?? 'Local';
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      tenant == null
                          ? CircleAvatar(
                              radius: 22,
                              backgroundColor: tokens.surfaceMuted,
                            )
                          : ClipOval(
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: AppAvatar(tenant: tenant, size: 44),
                              ),
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              tenantName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pedido #${order.orderNumber} · '
                              '${Formatters.dateTime(order.createdAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OrderStatusChip(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _OrderProgress(status: order.status),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Text(
                        Formatters.price(order.total),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _expanded ? 'Ocultar detalle' : 'Ver detalle',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _OrderDetail(order: order, tenant: tenant),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

/// Expanded area: item lines, total and the reorder / WhatsApp actions.
class _OrderDetail extends ConsumerWidget {
  const _OrderDetail({required this.order, required this.tenant});

  final OrderModel order;
  final TenantModel? tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Divider(height: 1, color: tokens.border),
          const SizedBox(height: 12),
          ref
              .watch(orderItemsProvider(order.id))
              .when(
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
                                '${Formatters.qtyLabel(item.quantity, item.unit)} x ${item.titleSnapshot}'
                                '${item.variant == null ? '' : ' (${item.variant})'}',
                              ),
                            ),
                            Text(Formatters.price(item.lineTotal)),
                          ],
                        ),
                      ),
                    const Divider(height: 16),
                    Row(
                      children: <Widget>[
                        const Expanded(child: Text('Subtotal')),
                        Text(Formatters.price(order.subtotal)),
                      ],
                    ),
                    OrderCostRows(order: order, dense: true),
                    const SizedBox(height: 4),
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          if (tenant != null) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('WhatsApp'),
                    onPressed: () => launchUrl(
                      buildWhatsAppUri(
                        tenant!.whatsapp,
                        'Hola ${tenant!.name}! '
                        'Te escribo por mi pedido #${order.orderNumber}.',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Volver a pedir'),
                    onPressed: () => _reorder(context, ref, tenant!, order),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
