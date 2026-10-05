import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/features/billing/data/models/plan_model.dart';
import 'package:all_commerce/features/billing/data/repositories/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminPlansView extends ConsumerWidget {
  const AdminPlansView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PlanModel>> plansAsync = ref.watch(plansProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin'),
        title: const Text('Precios de planes'),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: plansAsync.when(
              loading: () =>
                  const AppSkeletonList(itemCount: 3, itemHeight: 260),
              error: (Object e, StackTrace s) => AppErrorState(
                onRetry: () => ref.invalidate(plansProvider),
              ),
              data: (List<PlanModel> plans) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: <Widget>[
                  for (final PlanModel plan in plans)
                    _EditablePlanCard(plan: plan),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditablePlanCard extends ConsumerStatefulWidget {
  const _EditablePlanCard({required this.plan});

  final PlanModel plan;

  @override
  ConsumerState<_EditablePlanCard> createState() =>
      _EditablePlanCardState();
}

class _EditablePlanCardState extends ConsumerState<_EditablePlanCard> {
  late final TextEditingController _price;
  late final TextEditingController _aiLimit;
  late final TextEditingController _highlights;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
      text: widget.plan.priceArs.toStringAsFixed(0),
    );
    _aiLimit = TextEditingController(
      text: widget.plan.aiAnalysesPerMonth?.toString() ?? '',
    );
    _highlights =
        TextEditingController(text: widget.plan.highlights.join('\n'));
  }

  @override
  void dispose() {
    _price.dispose();
    _aiLimit.dispose();
    _highlights.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final num? price = num.tryParse(_price.text.trim());
    if (price == null || price < 0) {
      showAppSnackBar(context, 'Precio inválido', clearNavBar: false);
      return;
    }
    final String aiText = _aiLimit.text.trim();
    final int? aiLimit = aiText.isEmpty ? null : int.tryParse(aiText);
    if (aiText.isNotEmpty && (aiLimit == null || aiLimit < 0)) {
      showAppSnackBar(context, 'Límite de IA inválido', clearNavBar: false);
      return;
    }
    final List<String> highlights = _highlights.text
        .split('\n')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    setState(() => _saving = true);
    try {
      await ref.read(planRepositoryProvider).updatePlan(
            widget.plan.id,
            priceArs: price,
            highlights: highlights,
            aiAnalysesPerMonth: () => aiLimit,
          );
      ref.invalidate(plansProvider);
      if (!mounted) return;
      AppHaptics.success();
      showAppSnackBar(
        context,
        '${widget.plan.name} actualizado',
        clearNavBar: false,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'No se pudo guardar ${widget.plan.name}',
        clearNavBar: false,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.plan.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'máx. ${widget.plan.maxProducts} productos',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio ARS/mes',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _aiLimit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Análisis IA/mes',
                      hintText: 'Ilimitado',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _highlights,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Highlights (uno por línea)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
