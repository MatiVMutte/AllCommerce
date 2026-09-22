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

  Future<List<TenantModel>> listActive() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('tenants')
        .select()
        .eq('is_active', true)
        .order('name');
    return rows.map(TenantModel.fromJson).toList();
  }
}
