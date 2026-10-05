import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/features/admin/data/models/admin_models.dart';
import 'package:all_commerce/features/admin/data/repositories/admin_repository.dart';
import 'package:all_commerce/features/orders/data/services/whatsapp_message_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminTenantView extends ConsumerStatefulWidget {
  const AdminTenantView({required this.tenantId, super.key});

  final String tenantId;

  @override
  ConsumerState<AdminTenantView> createState() => _AdminTenantViewState();
}

class _AdminTenantViewState extends ConsumerState<AdminTenantView> {
  PlanType? _plan;
  DateTime? _expiresAt;
  bool? _isActive;
  bool _saving = false;

  bool get _dirty => _plan != null || _expiresAt != null || _isActive != null;

  Future<void> _pickDate(AdminTenantRow row) async {
    final DateTime initial = _expiresAt ?? row.planExpiresAt;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime.now())
          ? DateTime.now()
          : initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  void _addMonths(int months, AdminTenantRow row) {
    final DateTime base = _expiresAt ?? row.planExpiresAt;
    final DateTime now = DateTime.now();
    final DateTime start = base.isBefore(now) ? now : base;
    setState(() {
      _expiresAt = DateTime(start.year, start.month + months, start.day);
    });
  }

  Future<void> _save(AdminTenantRow row) async {
    final bool isActive = _isActive ?? row.isActive;
    if (!isActive && row.isActive) {
      final bool? ok = await showAppConfirmSheet(
        context,
        title: 'Desactivar local',
        message: 'El local dejará de ser visible y su dueño no podrá '
            'publicar productos. ¿Continuar?',
        confirmLabel: 'Desactivar',
        destructive: true,
      );
      if (ok != true) return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).setTenantPlan(
            tenantId: row.id,
            plan: _plan ?? row.plan,
            expiresAt: _expiresAt ?? row.planExpiresAt,
            isActive: isActive,
          );
      ref.invalidate(adminTenantsProvider);
      ref.invalidate(adminMetricsProvider);
      if (!mounted) return;
      AppHaptics.success();
      showAppSnackBar(context, 'Plan actualizado', clearNavBar: false);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'No se pudo actualizar el plan',
        clearNavBar: false,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdminTenantRow?> rowAsync =
        ref.watch(adminTenantProvider(widget.tenantId));
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin'),
        title: const Text('Local'),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: rowAsync.when(
              loading: () =>
                  const AppSkeletonList(itemCount: 4, itemHeight: 120),
              error: (Object e, StackTrace s) => AppErrorState(
                onRetry: () =>
                    ref.invalidate(adminTenantProvider(widget.tenantId)),
              ),
              data: (AdminTenantRow? row) {
                if (row == null) {
                  return const AppEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'El local no existe',
                  );
                }
                return _buildContent(row);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AdminTenantRow row) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final PlanType plan = _plan ?? row.plan;
    final DateTime expiresAt = _expiresAt ?? row.planExpiresAt;
    final bool isActive = _isActive ?? row.isActive;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        scheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      row.name.isEmpty ? '?' : row.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          row.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          row.slug,
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/s/${row.slug}'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Ver catálogo'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _Section('DUEÑO'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: row.ownerName ?? 'Sin nombre',
                    ),
                    Divider(height: 1, color: tokens.border),
                    _InfoRow(
                      icon: Icons.mail_outline_rounded,
                      label: row.ownerEmail ?? 'Sin email',
                      trailing: IconButton(
                        tooltip: 'Copiar email',
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: row.ownerEmail == null
                            ? null
                            : () {
                                Clipboard.setData(
                                  ClipboardData(text: row.ownerEmail!),
                                );
                                showAppSnackBar(
                                  context,
                                  'Email copiado',
                                  clearNavBar: false,
                                );
                              },
                      ),
                    ),
                    Divider(height: 1, color: tokens.border),
                    _InfoRow(
                      icon: Icons.phone_iphone_rounded,
                      label: row.ownerPhone ?? 'Sin teléfono',
                      trailing: IconButton(
                        tooltip: 'Escribir por WhatsApp',
                        icon: const Icon(Icons.chat_bubble_outline_rounded,
                            size: 18),
                        onPressed: row.ownerPhone == null
                            ? null
                            : () => launchUrl(
                                  buildWhatsAppUri(row.ownerPhone!, ''),
                                  mode: LaunchMode.externalApplication,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _Section('ACTIVIDAD'),
              const SizedBox(height: 8),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    _InfoRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Productos',
                      trailing: _Value('${row.productCount}'),
                    ),
                    Divider(height: 1, color: tokens.border),
                    _InfoRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Pedidos',
                      trailing: _Value('${row.orderCount}'),
                    ),
                    Divider(height: 1, color: tokens.border),
                    _InfoRow(
                      icon: Icons.schedule_outlined,
                      label: 'Último pedido',
                      trailing: _Value(
                        row.lastOrderAt == null
                            ? '—'
                            : Formatters.dateTime(row.lastOrderAt!),
                      ),
                    ),
                    Divider(height: 1, color: tokens.border),
                    _InfoRow(
                      icon: Icons.login_rounded,
                      label: 'Último ingreso',
                      trailing: _Value(
                        row.lastSignInAt == null
                            ? '—'
                            : Formatters.dateTime(row.lastSignInAt!),
                      ),
                    ),
                    Divider(height: 1, color: tokens.border),
                    _InfoRow(
                      icon: Icons.auto_awesome,
                      label: 'IA este mes',
                      trailing: _Value('${row.aiUsedMonth}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _Section('PLAN'),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SegmentedButton<PlanType>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<PlanType>>[
                        ButtonSegment<PlanType>(
                          value: PlanType.trial,
                          label: Text('Prueba'),
                        ),
                        ButtonSegment<PlanType>(
                          value: PlanType.inicial,
                          label: Text('Inicial'),
                        ),
                        ButtonSegment<PlanType>(
                          value: PlanType.crecimiento,
                          label: Text('Crecimiento'),
                        ),
                        ButtonSegment<PlanType>(
                          value: PlanType.pro,
                          label: Text('Pro'),
                        ),
                      ],
                      selected: <PlanType>{plan},
                      onSelectionChanged: (Set<PlanType> s) =>
                          setState(() => _plan = s.first),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _pickDate(row),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surfaceMuted,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.event_outlined,
                                    size: 18,
                                    color: tokens.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Vence '
                                      '${Formatters.dateTime(expiresAt).split(' ').first}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        for (final (String label, int months) in
                            <(String, int)>[
                              ('+1 mes', 1),
                              ('+3 meses', 3),
                              ('+12 meses', 12),
                            ])
                          ActionChip(
                            label: Text(label),
                            onPressed: () => _addMonths(months, row),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Local activo'),
                      value: isActive,
                      onChanged: (bool v) =>
                          setState(() => _isActive = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border(top: BorderSide(color: tokens.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _dirty && !_saving ? () => _save(row) : null,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar cambios'),
              ),
            ),
          ),
        ),
      ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: tokens.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: tokens.textPrimary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.tokens.textPrimary,
      ),
    );
  }
}
