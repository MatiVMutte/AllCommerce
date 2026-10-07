import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenantRepository {
  const TenantRepository(this._client);

  final SupabaseClient _client;

  Future<TenantModel?> getBySlug(String slug) async {
    final Map<String, dynamic>? row = await _client
        .from('tenants')
        .select()
        .eq('slug', slug)
        .maybeSingle();
    if (row == null) return null;
    return TenantModel.fromJson(row);
  }

  Future<TenantModel?> getById(String id) async {
    final Map<String, dynamic>? row = await _client
        .from('tenants')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return TenantModel.fromJson(row);
  }

  Future<List<TenantModel>> listActive() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('tenants')
        .select()
        .eq('is_active', true)
        .order('name');
    return rows.map(TenantModel.fromJson).toList();
  }

  Future<List<TenantModel>> listActiveByZone(String? zone) async {
    final PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
        .from('tenants')
        .select()
        .eq('is_active', true);
    final PostgrestTransformBuilder<List<Map<String, dynamic>>> ordered =
        zone == null || zone.isEmpty
            ? query.order('name')
            : query.eq('zone', zone).order('name');
    final List<Map<String, dynamic>> rows = await ordered;
    return rows.map(TenantModel.fromJson).toList();
  }

  Future<List<String>> listZones() async {
    final List<dynamic> rows = await _client.rpc<List<dynamic>>('public_zones');
    return rows.whereType<String>().where((String z) => z.isNotEmpty).toList();
  }
}
