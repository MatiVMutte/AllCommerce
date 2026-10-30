import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/features/admin/data/models/admin_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>(
      (Ref ref) => AdminRepository(ref.watch(supabaseClientProvider)),
    );

final FutureProvider<AdminMetrics> adminMetricsProvider =
    FutureProvider<AdminMetrics>(
      (Ref ref) => ref.watch(adminRepositoryProvider).metrics(),
    );

final FutureProvider<List<AdminTenantRow>> adminTenantsProvider =
    FutureProvider<List<AdminTenantRow>>(
      (Ref ref) => ref.watch(adminRepositoryProvider).tenantsOverview(),
    );

final adminTenantProvider = FutureProvider.autoDispose
    .family<AdminTenantRow?, String>((Ref ref, String id) async {
      final List<AdminTenantRow> rows = await ref.watch(
        adminTenantsProvider.future,
      );
      for (final AdminTenantRow row in rows) {
        if (row.id == id) return row;
      }
      return null;
    });

class AdminRepository {
  const AdminRepository(this._client);

  final SupabaseClient _client;

  Future<AdminMetrics> metrics() async {
    final Map<String, dynamic> row = await _client.rpc<Map<String, dynamic>>(
      'admin_metrics',
    );
    return AdminMetrics.fromJson(row);
  }

  Future<List<AdminTenantRow>> tenantsOverview() async {
    final List<dynamic> rows = await _client.rpc<List<dynamic>>(
      'admin_tenants_overview',
    );
    return rows
        .map((dynamic r) => AdminTenantRow.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> setTenantPlan({
    required String tenantId,
    required PlanType plan,
    required DateTime expiresAt,
    required bool isActive,
  }) async {
    await _client.rpc<void>(
      'admin_set_tenant_plan',
      params: <String, dynamic>{
        'p_tenant_id': tenantId,
        'p_plan': plan.id,
        'p_expires_at': expiresAt.toIso8601String(),
        'p_is_active': isActive,
      },
    );
  }

  Future<void> updateTenantLocation({
    required String tenantId,
    required String? zone,
    required String? address,
    required double? lat,
    required double? lng,
    required bool isClaimed,
  }) async {
    await _client.rpc<void>(
      'admin_update_tenant_location',
      params: <String, dynamic>{
        'p_tenant_id': tenantId,
        'p_zone': zone,
        'p_address': address,
        'p_lat': lat,
        'p_lng': lng,
        'p_is_claimed': isClaimed,
      },
    );
  }
}
