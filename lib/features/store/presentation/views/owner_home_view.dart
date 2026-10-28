import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/router/customer_mode.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/widgets/app_avatar.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_refresh_button.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/core/widgets/order_status_chip.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/billing/data/repositories/ai_usage_repository.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/models/sales_metrics.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:all_commerce/features/store/presentation/view_models/tenant_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class OwnerHomeView extends ConsumerStatefulWidget {
  const OwnerHomeView({super.key});

  @override
  ConsumerState<OwnerHomeView> createState() => _OwnerHomeViewState();
}

class _OwnerHomeViewState extends ConsumerState<OwnerHomeView> {
  /// Tenant providers are kept alive for the whole session; refresh the
  /// tenant row once per visit so plan changes made elsewhere are seen.
  String? _refreshedTenantId;

  @override
  Widget build(BuildContext context) {
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
            if (tenantId != null && tenantId != _refreshedTenantId) {
              _refreshedTenantId = tenantId;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ref.invalidate(tenantByIdProvider(tenantId));
                }
              });
            }
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
    final AiUsage? aiUsage = ref.watch(aiUsageProvider).value;
    final int pending = orders == null ? 0 : pendingCount(orders);
    final bool expiring = tenant.canPublish && tenant.daysLeft <= 3;
    final String planLine = tenant.plan == PlanType.free
        ? 'Plan Gratis · ${tenant.plan.maxProducts} productos'
        : (tenant.canPublish
            ? 'Plan ${tenant.plan.label} · ${tenant.daysLeft} días restantes'
            : 'Plan vencido');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      InkWell(
                        onTap: () => context.push('/owner/plans'),
                        child: Text(
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
                      ),
                    ],
                  ),
                ),
                AppRefreshButton(onRefresh: () => _refresh(ref)),
                const SizedBox(width: 6),
                _CircleIcon(
                  icon: Icons.travel_explore_rounded,
                  tooltip: 'Explorar locales (modo cliente)',
                  onTap: () {
                    ref.read(customerModeProvider.notifier).enterCustomerMode();
                    context.go('/');
                  },
                ),
                if (ref.watch(currentProfileProvider).value?.isAdmin ??
                    false) ...<Widget>[
                  const SizedBox(width: 6),
                  _CircleIcon(
                    icon: Icons.admin_panel_settings_outlined,
                    tooltip: 'Administración',
                    onTap: () => context.push('/admin'),
                  ),
                ],
                const SizedBox(width: 6),
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
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: tenant.isOpen ? tokens.success : tokens.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          tenant.isOpen ? 'Local abierto' : 'Local cerrado',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                        if (tenant.openingHours != null &&
                            tenant.openingHours!.trim().isNotEmpty)
                          Text(
                            tenant.openingHours!,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: tenant.isOpen,
                    onChanged: (_) async {
                      final bool ok = await ref
                          .read(tenantSettingsControllerProvider.notifier)
                          .toggleOpen(tenant);
                      if (ok && context.mounted) {
                        showAppSnackBar(
                          context,
                          !tenant.isOpen
                              ? 'Tu local figura como Abierto'
                              : 'Tu local figura como Cerrado',
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final List<Widget> cells = <Widget>[
                  _MetricCell(
                    value: products == null
                        ? '—'
                        : '${products.length}/'
                              '${tenant.plan.maxProducts}',
                    label: 'Productos',
                  ),
                  _MetricCell(
                    value: '$pending',
                    label: 'Pedidos nuevos',
                    highlight: pending > 0,
                  ),
                  _MetricCell(
                    value: tenant.canPublish
                        ? '${tenant.daysLeft} días'
                        : 'Vencido',
                    label: 'Plan',
                  ),
                  _MetricCell(
                    value: aiUsage == null
                        ? '—'
                        : '${aiUsage.used}/${aiUsage.limit ?? '∞'}',
                    label: 'IA',
                  ),
                ];
                return AppCard(
                  padding: EdgeInsets.zero,
                  child: c.maxWidth < 420
                      ? Column(
                          children: <Widget>[
                            IntrinsicHeight(
                              child: Row(
                                children: <Widget>[
                                  cells[0],
                                  _Divider(tokens: tokens),
                                  cells[1],
                                ],
                              ),
                            ),
                            Container(
                              height: 1,
                              color: tokens.border,
                            ),
                            IntrinsicHeight(
                              child: Row(
                                children: <Widget>[
                                  cells[2],
                                  _Divider(tokens: tokens),
                                  cells[3],
                                ],
                              ),
                            ),
                          ],
                        )
                      : IntrinsicHeight(
                          child: Row(
                            children: <Widget>[
                              cells[0],
                              _Divider(tokens: tokens),
                              cells[1],
                              _Divider(tokens: tokens),
                              cells[2],
                              _Divider(tokens: tokens),
                              cells[3],
                            ],
                          ),
                        ),
                );
              },
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Ventas del mes'),
            const SizedBox(height: 8),
            _SalesCard(
              metricsAsync: ref.watch(ownerSalesMetricsProvider(tenant.id)),
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
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(tenantByIdProvider(tenant.id));
    ref.invalidate(ownerProductsProvider(tenant.id));
    ref.invalidate(ownerOrdersProvider(tenant.id));
    ref.invalidate(ownerSalesMetricsProvider(tenant.id));
    ref.invalidate(aiUsageProvider);
    await ref
        .read(tenantByIdProvider(tenant.id).future)
        .catchError((Object _) => null);
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
            onPressed: () => context.push('/owner/plans'),
            child: const Text('Ver planes'),
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
            child: const Text('WhatsApp'),
          ),
        ],
      ),
    );
  }
}

const List<String> _monthNames = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "Ventas del mes": total del mes, comparativa con el mes anterior y
/// top 3 productos más pedidos.
class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.metricsAsync});

  final AsyncValue<SalesMetrics> metricsAsync;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return metricsAsync.when(
      loading: () => const AppSkeleton(height: 120),
      error: (Object e, StackTrace s) => const SizedBox.shrink(),
      data: (SalesMetrics m) {
        final double? delta = m.monthOverMonthDelta;
        return AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          Formatters.price(m.monthTotal),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${m.monthCount} pedidos en '
                          '${_monthNames[DateTime.now().month - 1]}',
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (delta != null)
                    _DeltaPill(delta: delta)
                  else if (m.monthCount > 0 && m.prevCount == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceMuted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Primer mes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              if (m.topProducts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Divider(height: 1, color: tokens.border),
                const SizedBox(height: 10),
                Text(
                  'MÁS PEDIDOS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: tokens.textTertiary,
                  ),
                ),
                for (final (int i, SalesTopProduct p)
                    in m.topProducts.indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: tokens.surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${p.quantity} u.',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          Formatters.price(p.revenue),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Green/red pill with the month-over-month percent change.
class _DeltaPill extends StatelessWidget {
  const _DeltaPill({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool up = delta >= 0;
    final Color color = up ? tokens.success : tokens.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
