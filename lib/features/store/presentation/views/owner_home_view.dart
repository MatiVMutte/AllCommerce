import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/widgets/app_avatar.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/core/widgets/order_status_chip.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class OwnerHomeView extends ConsumerWidget {
  const OwnerHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserModel?> profileAsync = ref.watch(
      currentProfileProvider,
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: profileAsync.when(
          loading: () => const AppSkeletonList(itemCount: 3, itemHeight: 96),
          error: (Object error, StackTrace stack) => AppErrorState(
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
          data: (UserModel? profile) {
            final String? tenantId = profile?.tenantId;
            if (tenantId == null) {
              return const AppEmptyState(
                icon: Icons.storefront_outlined,
                title: 'No encontramos tu local',
              );
            }
            final AsyncValue<TenantModel?> tenantAsync = ref.watch(
              tenantByIdProvider(tenantId),
            );
            return tenantAsync.when(
              loading: () =>
                  const AppSkeletonList(itemCount: 3, itemHeight: 96),
              error: (Object error, StackTrace stack) => AppErrorState(
                onRetry: () => ref.invalidate(tenantByIdProvider(tenantId)),
              ),
              data: (TenantModel? tenant) {
                if (tenant == null) {
                  return const AppEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No encontramos tu local',
                  );
                }
                return _OwnerPanel(tenant: tenant);
              },
            );
          },
        ),
      ),
    );
  }
}

/// Section title in the "Linear" style: small caps, tertiary color.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: context.tokens.textTertiary,
      ),
    );
  }
}

class _OwnerPanel extends ConsumerWidget {
  const _OwnerPanel({required this.tenant});

  final TenantModel tenant;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final bool? confirm = await showAppConfirmSheet(
      context,
      title: 'Cerrar sesión',
      message: 'Vas a salir de tu cuenta en este dispositivo.',
      confirmLabel: 'Cerrar sesión',
    );
    if (confirm == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final List<ProductModel>? products = ref
        .watch(ownerProductsProvider(tenant.id))
        .value;
    final List<OrderModel>? orders = ref
        .watch(ownerOrdersProvider(tenant.id))
        .value;
    final int pending = orders == null ? 0 : pendingCount(orders);
    final bool expiring = tenant.canPublish && tenant.daysLeft <= 3;
    final String planLine = tenant.canPublish
        ? 'Plan ${tenant.plan.label} · ${tenant.daysLeft} días restantes'
        : 'Plan vencido';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + FloatingNavBar.height,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                AppAvatar(tenant: tenant, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        tenant.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        planLine,
                        style: TextStyle(
                          fontSize: 13,
                          color: tenant.canPublish
                              ? (expiring
                                    ? tokens.warning
                                    : tokens.textSecondary)
                              : tokens.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                _CircleIcon(
                  icon: Icons.logout_rounded,
                  tooltip: 'Cerrar sesión',
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
            if (!tenant.canPublish) ...<Widget>[
              const SizedBox(height: 16),
              _PlanBanner(tenant: tenant),
            ],
            const SizedBox(height: 20),
            AppCard(
              padding: EdgeInsets.zero,
              child: IntrinsicHeight(
                child: Row(
                  children: <Widget>[
                    _MetricCell(
                      value: products == null
                          ? '—'
                          : '${products.length}/'
                                '${tenant.plan.maxProducts}',
                      label: 'Productos',
                    ),
                    _Divider(tokens: tokens),
                    _MetricCell(
                      value: '$pending',
                      label: 'Pedidos nuevos',
                      highlight: pending > 0,
                    ),
                    _Divider(tokens: tokens),
                    _MetricCell(
                      value: tenant.canPublish
                          ? '${tenant.daysLeft} días'
                          : 'Vencido',
                      label: 'Plan',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Últimos pedidos'),
            const SizedBox(height: 8),
            if (orders == null)
              const AppSkeleton(height: 120)
            else if (orders.isEmpty)
              const AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Todavía no llegaron pedidos',
              )
            else ...<Widget>[
              for (final OrderModel order in orders.take(5))
                _OrderRow(order: order),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/owner/orders'),
                  child: const Text('Ver todos'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const _SectionTitle('Tu catálogo'),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${ShareService.linkBase}/s/${tenant.slug}',
                      style: TextStyle(color: tokens.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.copy_outlined,
                      size: 18,
                      color: tokens.textSecondary,
                    ),
                    tooltip: 'Copiar link',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              'https://${ShareService.linkBase}/s/${tenant.slug}',
                        ),
                      );
                      if (context.mounted) {
                        showAppSnackBar(context, 'Link copiado');
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.ios_share_outlined,
                      size: 18,
                      color: tokens.textSecondary,
                    ),
                    tooltip: 'Compartir',
                    onPressed: () async {
                      final ShareResult result = await const ShareService()
                          .shareLink(
                            url: ShareService.catalogUrl(tenant.slug),
                            text: 'Mirá el catálogo de ${tenant.name}',
                          );
                      if (context.mounted && result == ShareResult.copied) {
                        showAppSnackBar(context, 'Link copiado');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Ver catálogo'),
                onPressed: () => context.push('/s/${tenant.slug}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        icon: Icon(icon, size: 18, color: tokens.textPrimary),
        onPressed: onTap,
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: highlight
                    ? Theme.of(context).colorScheme.primary
                    : tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: tokens.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: tokens.border);
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
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
                  Text(
                    '#${order.orderNumber} · '
                    '${order.customerNameSnapshot}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  OrderStatusChip(status: order.status),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
                const SizedBox(height: 2),
                Text(
                  Formatters.dateTime(order.createdAt),
                  style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact warning banner shown when the plan no longer allows publishing.
class _PlanBanner extends StatelessWidget {
  const _PlanBanner({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final String whatsapp = AppConfig.supportWhatsapp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.lock_clock_outlined, color: tokens.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tu prueba terminó. Activá un plan para seguir '
              'publicando.',
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
            ),
          ),
          TextButton(
            onPressed: whatsapp.isEmpty
                ? null
                : () => launchUrl(
                    Uri.parse(
                      'https://wa.me/$whatsapp?text='
                      '${Uri.encodeComponent('Hola! Quiero activar un plan de AllCommerce para mi local ${tenant.name} (${tenant.slug}).')}',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }
}
