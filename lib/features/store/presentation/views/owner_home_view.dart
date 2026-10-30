import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/router/customer_mode.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_motion.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/app_avatar.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_refresh_button.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/core/widgets/order_status_chip.dart';
import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/billing/data/repositories/ai_usage_repository.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/models/sales_metrics.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:all_commerce/features/store/presentation/view_models/tenant_settings_controller.dart';
import 'package:animate_do/animate_do.dart';
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
    final bool wide = AdaptiveNavShell.isWide(context);

    /// One column on phones; two columns on wide screens (status/metrics/
    /// checklist left, sales/orders/catalog right) so the dashboard uses
    /// the desktop space instead of centering a narrow column.
    Widget twoCols(List<Widget> left, List<Widget> right) => wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: Column(children: left)),
              const SizedBox(width: 28),
              Expanded(child: Column(children: right)),
            ],
          )
        : Column(children: <Widget>[...left, ...right]);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 1100 : 720),
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              24 + (wide ? 0 : FloatingNavBar.height),
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
                      ref
                          .read(customerModeProvider.notifier)
                          .enterCustomerMode();
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
              twoCols(
                <Widget>[
                  _FadeInStep(
                    step: 0,
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: tenant.isOpen
                                  ? tokens.success
                                  : tokens.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  tenant.isOpen
                                      ? 'Local abierto'
                                      : 'Local cerrado',
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
                                  .read(
                                    tenantSettingsControllerProvider.notifier,
                                  )
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
                  ),
                  const SizedBox(height: 16),
                  _FadeInStep(
                    step: 1,
                    child: LayoutBuilder(
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
                                    Container(height: 1, color: tokens.border),
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
                  ),
                  if (products != null)
                    _FadeInStep(
                      step: 2,
                      child: _ActivationChecklistCard(
                        tenant: tenant,
                        products: products,
                      ),
                    ),
                  _FadeInStep(
                    step: 3,
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 16),
                        _QuickActionsCard(tenant: tenant),
                        const SizedBox(height: 16),
                        _TipsCard(
                          tips: <({IconData icon, String text, Color color})>[
                            if (pending > 0)
                              (
                                icon: Icons.notifications_active_outlined,
                                text:
                                    'Tenés $pending pedidos nuevos esperando respuesta',
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            if (products != null)
                              if (products.any(
                                (ProductModel p) =>
                                    p.isActive &&
                                    (p.imageUrl == null || p.imageUrl!.isEmpty),
                              ))
                                (
                                  icon: Icons.photo_library_outlined,
                                  text: 'Hay productos sin foto: la foto vende el doble',
                                  color: tokens.warning,
                                ),
                            if (products != null)
                              if (products.any(
                                (ProductModel p) =>
                                    p.isActive && p.trackStock && p.stock <= 3,
                              ))
                                (
                                  icon: Icons.inventory_2_outlined,
                                  text: 'Stock bajo en algunos productos: actualizá las cantidades',
                                  color: tokens.warning,
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                <Widget>[
                  const _SectionTitle('Ventas del mes'),
                  const SizedBox(height: 8),
                  _FadeInStep(
                    step: 4,
                    child: _SalesCard(
                      metricsAsync: ref.watch(
                        ownerSalesMetricsProvider(tenant.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _WeeklySalesCard(orders: orders ?? const <OrderModel>[]),
                  if (pending > 0) ...<Widget>[
                    const SizedBox(height: 28),
                    const _SectionTitle('Pedidos nuevos'),
                    const SizedBox(height: 8),
                    for (final OrderModel o
                        in (orders ?? const <OrderModel>[])
                            .where(
                              (OrderModel o) =>
                                  o.status == OrderStatus.requested,
                            )
                            .take(3))
                      _OrderRow(order: o),
                  ],
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
                    for (final (int i, OrderModel order)
                        in orders.take(5).indexed)
                      _FadeInStep(
                        step: 4 + i,
                        child: _OrderRow(order: order),
                      ),
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
                  _FadeInStep(
                    step: 9,
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                              final ShareResult
                              result = await const ShareService().shareLink(
                                url: ShareService.catalogUrl(tenant.slug),
                                text:
                                    'Mirá el catálogo de ${tenant.name}: precios actualizados y pedidos directo por WhatsApp',
                              );
                              if (context.mounted &&
                                  result == ShareResult.copied) {
                                showAppSnackBar(context, 'Link copiado');
                              }
                            },
                          ),
                        ],
                      ),
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
    final Color primary = Theme.of(context).colorScheme.primary;
    Widget dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
    );
    if (AppMotion.loopsEnabled(context)) {
      dot = Pulse(
        infinite: true,
        duration: const Duration(milliseconds: 1800),
        child: dot,
      );
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: highlight ? primary : tokens.textPrimary,
                  ),
                ),
                if (highlight) ...<Widget>[const SizedBox(width: 5), dot],
              ],
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

/// Staggered [FadeInUp] entrance used across the owner dashboard sections.
class _FadeInStep extends StatelessWidget {
  const _FadeInStep({required this.step, required this.child});

  final int step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppMotion.enabled(context)) return child;
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      delay: Duration(milliseconds: step * 60),
      from: 16,
      child: child,
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
                for (final (int i, SalesTopProduct p) in m.topProducts.indexed)
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

class _ActivationStep {
  const _ActivationStep({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;
}

class _ActivationChecklistCard extends StatelessWidget {
  const _ActivationChecklistCard({
    required this.tenant,
    required this.products,
  });

  final TenantModel tenant;
  final List<ProductModel> products;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    final int activeProducts = products
        .where((ProductModel p) => p.isActive)
        .length;
    final bool hasLogo =
        tenant.logoUrl != null && tenant.logoUrl!.trim().isNotEmpty;
    final bool hasLocation = tenant.lat != null && tenant.lng != null;
    final bool hasHoursOrPayments =
        (tenant.openingHours?.trim().isNotEmpty ?? false) ||
        (tenant.transferAlias?.trim().isNotEmpty ?? false) ||
        (tenant.mercadoPagoLink?.trim().isNotEmpty ?? false);
    final bool hasThreeProducts = activeProducts >= 3;

    final List<_ActivationStep> steps = <_ActivationStep>[
      _ActivationStep(
        title: 'Subí el logo de tu local',
        subtitle: 'Le da identidad a tu catálogo y tarjeta del directorio',
        done: hasLogo,
        onTap: () => context.go('/owner/settings'),
      ),
      _ActivationStep(
        title: 'Marcá tu ubicación en el mapa',
        subtitle: 'Para que los vecinos te encuentren en el mapa',
        done: hasLocation,
        onTap: () => context.go('/owner/settings'),
      ),
      _ActivationStep(
        title: 'Cargá horarios o alias de cobro',
        subtitle: 'Ahorrá preguntas repetidas por WhatsApp',
        done: hasHoursOrPayments,
        onTap: () => context.go('/owner/settings'),
      ),
      _ActivationStep(
        title: 'Publicá al menos 3 productos ($activeProducts/3)',
        subtitle: 'Usá la cámara con IA para cargarlos en segundos',
        done: hasThreeProducts,
        onTap: () => context.push('/owner/products/new'),
      ),
    ];

    final int completed = steps.where((_ActivationStep s) => s.done).length;
    if (completed == steps.length) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.rocket_launch_outlined, size: 18, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dejá tu catálogo listo para vender',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$completed/${steps.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: completed / steps.length,
                minHeight: 6,
                backgroundColor: tokens.surfaceMuted,
              ),
            ),
            const SizedBox(height: 8),
            for (final _ActivationStep step in steps)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: step.done ? null : step.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        step.done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: step.done ? tokens.success : tokens.textTertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: step.done
                                    ? tokens.textSecondary
                                    : tokens.textPrimary,
                                decoration: step.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (!step.done)
                              Text(
                                step.subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!step.done)
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: tokens.textTertiary,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Quick action shortcuts for the most common owner tasks.
class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: <Widget>[
                Icon(icon, size: 22, color: tokens.textPrimary),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: <Widget>[
          action(
            Icons.add_a_photo_outlined,
            'Subir\nproducto',
            () => context.push('/owner/products/new'),
          ),
          action(
            Icons.ios_share_outlined,
            'Compartir\ncatálogo',
            () => const ShareService().shareLink(
              url: ShareService.catalogUrl(tenant.slug),
              text: 'Mirá el catálogo de ${tenant.name}',
            ),
          ),
          action(Icons.link_rounded, 'Copiar\nlink', () async {
            await Clipboard.setData(
              ClipboardData(
                text: 'https://${ShareService.linkBase}/s/${tenant.slug}',
              ),
            );
            if (context.mounted) showAppSnackBar(context, 'Link copiado');
          }),
          action(
            Icons.storefront_outlined,
            'Ver como\ncliente',
            () => context.push('/s/${tenant.slug}'),
          ),
        ],
      ),
    );
  }
}

/// Contextual tips computed from live data (pending orders, missing
/// photos, low stock, plan status).
class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.tips});

  final List<({IconData icon, String text, Color color})> tips;

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SizedBox.shrink();
    final AppTokens tokens = context.tokens;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final ({IconData icon, String text, Color color}) tip in tips)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: <Widget>[
                  Icon(tip.icon, size: 18, color: tip.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip.text,
                      style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Mini bar chart of sales totals for the last 7 days (built from the
/// already-loaded orders list, no extra queries).
class _WeeklySalesCard extends StatelessWidget {
  const _WeeklySalesCard({required this.orders});

  final List<OrderModel> orders;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final DateTime now = DateTime.now();
    final List<double> totals = List<double>.filled(7, 0);
    final List<String> labels = <String>[];
    const List<String> dow = <String>['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sa', 'Do'];
    for (int i = 0; i < 7; i++) {
      final DateTime day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i));
      labels.add(dow[day.weekday - 1]);
      for (final OrderModel o in orders) {
        final DateTime d = o.createdAt.toLocal();
        if (d.year == day.year && d.month == day.month && d.day == day.day) {
          totals[i] += o.total;
        }
      }
    }
    final double maxV = totals.fold<double>(
      0,
      (double a, double b) => a > b ? a : b,
    );
    final double week = totals.fold<double>(0, (double a, double b) => a + b);
    // Same window one week earlier (days 7–13 ago) for the delta chip.
    final DateTime today = DateTime(now.year, now.month, now.day);
    double prevWeek = 0;
    for (final OrderModel o in orders) {
      final DateTime d = o.createdAt.toLocal();
      final int daysAgo = today
          .difference(DateTime(d.year, d.month, d.day))
          .inDays;
      if (daysAgo >= 7 && daysAgo < 14) prevWeek += o.total;
    }
    final double? deltaPct = prevWeek > 0
        ? (week - prevWeek) / prevWeek * 100
        : null;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Esta semana: ${Formatters.price(week)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              if (deltaPct != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (deltaPct >= 0 ? tokens.success : tokens.danger)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${deltaPct >= 0 ? '+' : ''}'
                    '${deltaPct.toStringAsFixed(0)}% vs sem. anterior',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: deltaPct >= 0 ? tokens.success : tokens.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          height: maxV <= 0
                              ? 4
                              : (totals[i] / maxV * 56).clamp(4.0, 56.0),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: totals[i] > 0
                                ? Theme.of(context).colorScheme.primary
                                : tokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: tokens.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
