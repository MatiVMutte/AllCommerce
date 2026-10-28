import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_refresh_button.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/features/admin/data/models/admin_models.dart';
import 'package:all_commerce/features/admin/data/repositories/admin_repository.dart';
import 'package:all_commerce/features/admin/presentation/view_models/admin_tenant_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _TenantFilter { all, paying, trial, expired, inactive }

class AdminHomeView extends ConsumerStatefulWidget {
  const AdminHomeView({super.key});

  @override
  ConsumerState<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends ConsumerState<AdminHomeView> {
  final TextEditingController _search = TextEditingController();
  _TenantFilter _filter = _TenantFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AdminTenantRow> _applyFilters(List<AdminTenantRow> rows) {
    final String q = _search.text.trim().toLowerCase();
    return rows.where((AdminTenantRow r) {
      final AdminTenantStatus status = adminTenantStatus(r);
      final bool filterOk = switch (_filter) {
        _TenantFilter.all => true,
        _TenantFilter.paying => status == AdminTenantStatus.paying,
        _TenantFilter.trial => status == AdminTenantStatus.trial,
        _TenantFilter.expired => status == AdminTenantStatus.expired,
        _TenantFilter.inactive => status == AdminTenantStatus.inactive,
      };
      if (!filterOk || q.isEmpty) return filterOk;
      return r.name.toLowerCase().contains(q) ||
          r.slug.toLowerCase().contains(q) ||
          (r.ownerName ?? '').toLowerCase().contains(q) ||
          (r.ownerEmail ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final AsyncValue<AdminMetrics> metricsAsync =
        ref.watch(adminMetricsProvider);
    final AsyncValue<List<AdminTenantRow>> tenantsAsync =
        ref.watch(adminTenantsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/'),
        title: const Text('AllCommerce · Admin'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppRefreshButton(
              onRefresh: () async {
                ref.invalidate(adminMetricsProvider);
                ref.invalidate(adminTenantsProvider);
                await ref
                    .read(adminTenantsProvider.future)
                    .catchError(
                      (Object _) => const <AdminTenantRow>[],
                    );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(adminMetricsProvider);
                ref.invalidate(adminTenantsProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: <Widget>[
                  metricsAsync.when(
                    loading: () => const _MetricsSkeleton(),
                    error: (Object e, StackTrace s) => AppErrorState(
                      onRetry: () => ref.invalidate(adminMetricsProvider),
                    ),
                    data: (AdminMetrics m) => _MetricsGrid(metrics: m),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push('/admin/plans'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.sell_outlined,
                            size: 18,
                            color: tokens.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Precios de planes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: tokens.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle('LOCALES'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, slug, dueño o email',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: tokens.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        for (final (_TenantFilter f, String label) in
                            <(_TenantFilter, String)>[
                              (_TenantFilter.all, 'Todos'),
                              (_TenantFilter.paying, 'Pagando'),
                              (_TenantFilter.trial, 'Prueba'),
                              (_TenantFilter.expired, 'Vencidos'),
                              (_TenantFilter.inactive, 'Inactivos'),
                            ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: _filter == f,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _filter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  tenantsAsync.when(
                    loading: () => Column(
                      children: <Widget>[
                        for (int i = 0; i < 5; i++) ...<Widget>[
                          const AppSkeleton(height: 64, radius: 14),
                          if (i < 4) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                    error: (Object e, StackTrace s) => AppErrorState(
                      onRetry: () => ref.invalidate(adminTenantsProvider),
                    ),
                    data: (List<AdminTenantRow> rows) {
                      final List<AdminTenantRow> filtered =
                          _applyFilters(rows);
                      if (filtered.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.storefront_outlined,
                          title: 'Sin locales',
                          subtitle:
                              'No hay locales que coincidan con el filtro.',
                        );
                      }
                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < filtered.length; i++) ...<Widget>[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  color: tokens.border,
                                ),
                              _TenantRow(row: filtered[i]),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

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

class _MetricsSkeleton extends StatelessWidget {
  const _MetricsSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: const <Widget>[
        AppSkeleton(height: double.infinity, radius: 20),
        AppSkeleton(height: double.infinity, radius: 20),
        AppSkeleton(height: double.infinity, radius: 20),
        AppSkeleton(height: double.infinity, radius: 20),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final AdminMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: <Widget>[
            _MetricCell(
              label: 'Locales pagando',
              value: '${metrics.tenantsPaying}',
              color: scheme.primary,
            ),
            _MetricCell(
              label: 'En prueba',
              value: '${metrics.tenantsTrial}',
            ),
            _MetricCell(
              label: 'Vencidos',
              value: '${metrics.tenantsExpired}',
              color: metrics.tenantsExpired > 0 ? tokens.danger : null,
            ),
            _MetricCell(
              label: 'MRR',
              value: Formatters.price(metrics.mrrArs),
            ),
            _MetricCell(
              label: 'Pedidos este mes',
              value: '${metrics.ordersMonth}',
            ),
            _MetricCell(
              label: 'Análisis IA este mes',
              value: '${metrics.aiMonth}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Clientes registrados ${metrics.customersTotal} · '
          'Pedidos totales ${metrics.ordersTotal}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: tokens.textTertiary),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color ?? tokens.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _TenantRow extends StatelessWidget {
  const _TenantRow({required this.row});

  final AdminTenantRow row;

  static const List<String> _months = <String>[
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  String _expiryText(AdminTenantStatus status) {
    final DateTime d = row.planExpiresAt;
    final String date = '${d.day} ${_months[d.month - 1]}';
    return status == AdminTenantStatus.expired
        ? 'venció $date'
        : 'vence $date';
  }

  Color _dotColor(
    AppTokens tokens,
    ColorScheme scheme,
    AdminTenantStatus status,
  ) {
    return switch (status) {
      AdminTenantStatus.paying => tokens.success,
      AdminTenantStatus.trial => scheme.primary,
      AdminTenantStatus.expired => tokens.danger,
      AdminTenantStatus.inactive => tokens.textTertiary,
    };
  }

  String _statusLabel(AdminTenantStatus status) {
    return switch (status) {
      AdminTenantStatus.paying => row.plan.label,
      AdminTenantStatus.trial => 'Prueba',
      AdminTenantStatus.expired => 'Vencido',
      AdminTenantStatus.inactive => 'Inactivo',
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AdminTenantStatus status = adminTenantStatus(row);
    return InkWell(
      onTap: () => context.push('/admin/tenants/${row.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primary.withValues(alpha: 0.1),
              child: Text(
                row.name.isEmpty ? '?' : row.name[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    '${row.slug} · ${row.ownerName ?? 'sin dueño'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _dotColor(tokens, scheme, status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _expiryText(status),
                  style: TextStyle(
                    fontSize: 12,
                    color: status == AdminTenantStatus.expired
                        ? tokens.danger
                        : tokens.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
