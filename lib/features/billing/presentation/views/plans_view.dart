import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/billing/data/models/plan_model.dart';
import 'package:all_commerce/features/billing/data/repositories/plan_repository.dart';
import 'package:all_commerce/features/orders/data/services/whatsapp_message_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class PlansView extends ConsumerStatefulWidget {
  const PlansView({super.key});

  @override
  ConsumerState<PlansView> createState() => _PlansViewState();
}

class _PlansViewState extends ConsumerState<PlansView> {
  /// Refresh the cached tenant row once per visit so plan changes (e.g. made
  /// from the admin panel) are reflected.
  String? _refreshedTenantId;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final AsyncValue<List<PlanModel>> plansAsync = ref.watch(plansProvider);
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;
    if (tenantId != null && tenantId != _refreshedTenantId) {
      _refreshedTenantId = tenantId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(tenantByIdProvider(tenantId));
      });
    }
    final TenantModel? tenant = tenantId == null
        ? null
        : ref.watch(tenantByIdProvider(tenantId)).value;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/owner'),
        title: const Text('Planes'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: plansAsync.when(
              loading: () =>
                  const AppSkeletonList(itemCount: 3, itemHeight: 220),
              error: (Object e, StackTrace s) => AppErrorState(
                onRetry: () => ref.invalidate(plansProvider),
              ),
              data: (List<PlanModel> plans) {
                final List<PlanModel> visible = plans
                    .where((PlanModel p) => p.id != PlanType.trial)
                    .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  children: <Widget>[
                    Text(
                      'Elegí el plan que acompañe a tu local',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                    if (tenant != null && tenant.plan == PlanType.trial &&
                        tenant.canPublish) ...<Widget>[
                      const SizedBox(height: 16),
                      _TrialBanner(daysLeft: tenant.daysLeft),
                    ],
                    if (tenant != null && tenant.plan == PlanType.free) ...<Widget>[
                      const SizedBox(height: 16),
                      _FreeBanner(productsUsed: tenant.plan.maxProducts),
                    ],
                    const SizedBox(height: 20),
                    for (final PlanModel plan in visible)
                      _PlanCard(
                        plan: plan,
                        current: plan.id == tenant?.plan,
                        onChoose: plan.id == PlanType.free
                            ? null
                            : () => _contact(context, plan, tenant, profile),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'El pago se coordina por WhatsApp. Pronto vas a poder '
                      'pagar desde la app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textTertiary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _contact(
    BuildContext context,
    PlanModel plan,
    TenantModel? tenant,
    UserModel? profile,
  ) {
    final String support = AppConfig.supportWhatsapp;
    if (support.isEmpty) return;
    final String price = plan.priceArs > 0
        ? ' (${Formatters.price(plan.priceArs)}/mes)'
        : '';
    launchUrl(
      buildWhatsAppUri(
        support,
        'Hola! Soy ${profile?.fullName ?? ''} de ${tenant?.name ?? 'mi local'} '
        '(${ShareService.linkBase}/s/${tenant?.slug ?? ''}) y quiero activar el plan '
        '${plan.name}$price.',
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.daysLeft});

  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool warn = daysLeft <= 3;
    final Color color = warn ? tokens.warning : tokens.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.schedule_outlined, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tu prueba termina en $daysLeft días',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeBanner extends StatelessWidget {
  const _FreeBanner({required this.productsUsed});

  final int productsUsed;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 18, color: tokens.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Estás en el plan Gratis con $productsUsed productos incluidos. '
              'Pagá solo cuando quieras crecer.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.current,
    this.onChoose,
  });

  final PlanModel plan;
  final bool current;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool featured = plan.id == PlanType.crecimiento;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        border: current
            ? Border.all(color: scheme.primary, width: 2)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    plan.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (current)
                  _Pill('Tu plan actual', scheme.primary, tokens)
                else if (featured)
                  _Pill(
                    'Más elegido',
                    tokens.surfaceMuted,
                    tokens,
                    foreground: tokens.textSecondary,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  plan.priceArs > 0
                      ? Formatters.price(plan.priceArs)
                      : 'Consultar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                if (plan.priceArs > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      '/mes',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            for (final String h in plan.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.check_rounded,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        h,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: current
                  ? const FilledButton.tonal(
                      onPressed: null,
                      child: Text('Plan actual'),
                    )
                  : plan.id == PlanType.free
                      ? const FilledButton.tonal(
                          onPressed: null,
                          child: Text('Incluido gratis'),
                        )
                      : FilledButton(
                          onPressed: onChoose,
                          child: const Text('Quiero este plan'),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.background, this.tokens, {this.foreground});

  final String text;
  final Color background;
  final AppTokens tokens;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground ?? Colors.white,
        ),
      ),
    );
  }
}
