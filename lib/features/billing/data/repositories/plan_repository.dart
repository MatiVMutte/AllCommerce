import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/features/billing/data/models/plan_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<PlanRepository> planRepositoryProvider =
    Provider<PlanRepository>(
      (Ref ref) => PlanRepository(ref.watch(supabaseClientProvider)),
    );

final FutureProvider<List<PlanModel>> plansProvider =
    FutureProvider<List<PlanModel>>(
      (Ref ref) => ref.watch(planRepositoryProvider).listPlans(),
    );

class PlanRepository {
  const PlanRepository(this._client);

  final SupabaseClient _client;

  Future<List<PlanModel>> listPlans() async {
    final List<dynamic> rows = await _client
        .from('plans')
        .select()
        .order('sort_order');
    return rows
        .map((dynamic r) => PlanModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Admin-only (RLS): updates price, AI cap and highlights.
  Future<void> updatePlan(
    PlanType id, {
    num? priceArs,
    List<String>? highlights,
    int? Function()? aiAnalysesPerMonth,
  }) async {
    final Map<String, dynamic> update = <String, dynamic>{};
    if (priceArs != null) update['price_ars'] = priceArs;
    if (highlights != null) update['highlights'] = highlights;
    if (aiAnalysesPerMonth != null) {
      update['ai_analyses_per_month'] = aiAnalysesPerMonth();
    }
    await _client.from('plans').update(update).eq('id', id.id);
  }
}
