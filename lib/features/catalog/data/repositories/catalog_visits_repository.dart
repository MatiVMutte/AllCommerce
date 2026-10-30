import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<CatalogVisitsRepository> catalogVisitsRepositoryProvider =
    Provider<CatalogVisitsRepository>((Ref ref) {
      // Tests and early boot may lack prefs/Supabase — degrade to no-op
      // instead of throwing (a throw here schedules a provider retry).
      SupabaseClient? client;
      SharedPreferences? prefs;
      try {
        client = ref.watch(supabaseClientProvider);
      } catch (_) {}
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (_) {}
      return CatalogVisitsRepository(client, prefs);
    });

/// (semana, total) de visitas al catálogo del local.
class CatalogVisitCounts {
  const CatalogVisitCounts({required this.week, required this.total});

  final int week;
  final int total;

  factory CatalogVisitCounts.fromJson(Map<String, dynamic> json) {
    return CatalogVisitCounts(
      week: (json['week'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class CatalogVisitsRepository {
  CatalogVisitsRepository(this._client, this._prefs);

  final SupabaseClient? _client;
  final SharedPreferences? _prefs;

  /// In-flight guard: recordVisit may be called on every catalog rebuild.
  final Set<String> _recorded = <String>{};

  /// Logs a catalog view, at most once per device/day/tenant so refreshes
  /// and the owner browsing their own store don't inflate the metric.
  Future<void> recordVisit(String tenantId) async {
    final SupabaseClient? client = _client;
    if (client == null) return;
    final String key = 'visit_$tenantId';
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_prefs?.getString(key) == today || !_recorded.add(key)) return;
    try {
      await client.from('catalog_visits').insert(<String, dynamic>{
        'tenant_id': tenantId,
      });
      await _prefs?.setString(key, today);
    } catch (_) {
      _recorded.remove(key);
      // Visit counting must never break the catalog.
    }
  }

  /// Never throws — the panel shows zeros rather than breaking on a
  /// network/RLS failure (visit counts are non-critical).
  Future<CatalogVisitCounts> counts(String tenantId) async {
    final SupabaseClient? client = _client;
    if (client == null) return const CatalogVisitCounts(week: 0, total: 0);
    try {
      final Object? data = await client.rpc(
        'catalog_visit_counts',
        params: <String, dynamic>{'p_tenant_id': tenantId},
      );
      if (data == null) return const CatalogVisitCounts(week: 0, total: 0);
      return CatalogVisitCounts.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return const CatalogVisitCounts(week: 0, total: 0);
    }
  }
}

final catalogVisitCountsProvider = FutureProvider.autoDispose
    .family<CatalogVisitCounts, String>(
      (Ref ref, String tenantId) =>
          ref.watch(catalogVisitsRepositoryProvider).counts(tenantId),
    );
