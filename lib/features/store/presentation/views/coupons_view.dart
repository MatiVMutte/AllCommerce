import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_refresh_button.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/store/data/models/coupon_model.dart';
import 'package:all_commerce/features/store/presentation/view_models/coupon_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owner screen to create/activate/delete discount coupons
/// (code + discount percent). Customers apply the code at checkout.
class CouponsView extends ConsumerWidget {
  const CouponsView({super.key});

  static final RegExp _codeRe = RegExp(r'^[A-Z0-9]{3,20}$');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final String? tenantId = ref.watch(currentProfileProvider).value?.tenantId;
    if (tenantId == null) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.storefront_outlined,
          title: 'No encontramos tu local',
        ),
      );
    }
    final AsyncValue<List<CouponModel>> couponsAsync = ref.watch(
      ownerCouponsProvider(tenantId),
    );
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/owner'),
        title: const Text('Cupones'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppRefreshButton(
              onRefresh: () async =>
                  ref.invalidate(ownerCouponsProvider(tenantId)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Creá códigos de descuento para tus clientes. '
                        'Los aplican al confirmar el pedido.',
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nuevo cupón'),
                        onPressed: () =>
                            _showCreateSheet(context, ref, tenantId),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: couponsAsync.when(
                    loading: () =>
                        const AppSkeletonList(itemCount: 4, itemHeight: 64),
                    error: (Object e, StackTrace s) => AppErrorState(
                      onRetry: () =>
                          ref.invalidate(ownerCouponsProvider(tenantId)),
                    ),
                    data: (List<CouponModel> coupons) {
                      if (coupons.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.local_offer_outlined,
                          title: 'Todavía no tenés cupones',
                          subtitle: 'Creá uno como PROMO10 y compartilo con tus clientes.',
                        );
                      }
                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          AdaptiveNavShell.isWide(context) ? 24 : 96,
                        ),
                        itemCount: coupons.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int i) =>
                            _CouponTile(coupon: coupons[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref, String tenantId) {
    final TextEditingController codeCtrl = TextEditingController();
    final TextEditingController pctCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        bool busy = false;
        String? error;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Future<void> save() async {
              final String code = codeCtrl.text.trim().toUpperCase();
              final int? pct = int.tryParse(pctCtrl.text.trim());
              if (!_codeRe.hasMatch(code)) {
                setState(
                  () => error = 'El código debe tener 3 a 20 letras/números (sin espacios).',
                );
                return;
              }
              if (pct == null || pct < 1 || pct > 100) {
                setState(() => error = 'El descuento debe ser entre 1 y 100%.');
                return;
              }
              setState(() {
                busy = true;
                error = null;
              });
              try {
                await ref
                    .read(couponRepositoryProvider)
                    .create(
                      tenantId: tenantId,
                      code: code,
                      discountPercent: pct,
                    );
                ref.invalidate(ownerCouponsProvider(tenantId));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  showAppSnackBar(context, 'Cupón $code creado');
                }
              } catch (_) {
                setState(() {
                  busy = false;
                  error =
                      'No se pudo crear: el código ya existe o '
                      'hubo un error de red.';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Nuevo cupón',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      hintText: 'PROMO10',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pctCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Descuento %',
                      hintText: '10',
                      suffixText: '%',
                    ),
                  ),
                  if (error != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? 'Creando...' : 'Crear cupón'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CouponTile extends ConsumerWidget {
  const _CouponTile({required this.coupon});

  final CouponModel coupon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final String? tenantId = ref.watch(currentProfileProvider).value?.tenantId;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              coupon.code,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: tokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '-${coupon.discountPercent}%',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tokens.success,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              coupon.isActive ? 'Activo' : 'Pausado',
              style: TextStyle(
                fontSize: 12,
                color: coupon.isActive ? tokens.success : tokens.textTertiary,
              ),
            ),
          ),
          Switch.adaptive(
            value: coupon.isActive,
            onChanged: (bool v) async {
              try {
                await ref
                    .read(couponRepositoryProvider)
                    .setActive(coupon.id, active: v);
                if (tenantId != null) {
                  ref.invalidate(ownerCouponsProvider(tenantId));
                }
              } catch (e) {
                if (context.mounted) showErrorSnackBar(context, e);
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: tokens.danger),
            tooltip: 'Eliminar cupón',
            onPressed: () async {
              final bool? ok = await showAppConfirmSheet(
                context,
                title: '¿Eliminar el cupón ${coupon.code}?',
                message: 'Los clientes no van a poder usarlo más.',
                confirmLabel: 'Eliminar',
                destructive: true,
              );
              if (ok != true || !context.mounted) return;
              try {
                await ref.read(couponRepositoryProvider).delete(coupon.id);
                if (tenantId != null) {
                  ref.invalidate(ownerCouponsProvider(tenantId));
                }
                if (context.mounted) {
                  showAppSnackBar(context, 'Cupón eliminado');
                }
              } catch (e) {
                if (context.mounted) showErrorSnackBar(context, e);
              }
            },
          ),
        ],
      ),
    );
  }
}
