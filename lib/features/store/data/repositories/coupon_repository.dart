import 'package:all_commerce/features/store/data/models/coupon_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CouponRepository {
  const CouponRepository(this._client);

  final SupabaseClient _client;

  Future<List<CouponModel>> list(String tenantId) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('coupons')
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
    return rows.map(CouponModel.fromJson).toList();
  }

  Future<CouponModel> create({
    required String tenantId,
    required String code,
    required String discountType,
    int? discountPercent,
    double? discountAmount,
  }) async {
    final Map<String, dynamic> row = await _client
        .from('coupons')
        .insert(<String, dynamic>{
          'tenant_id': tenantId,
          'code': code.trim().toUpperCase(),
          'discount_type': discountType,
          'discount_percent': discountPercent,
          'discount_amount': discountAmount,
        })
        .select()
        .single();
    return CouponModel.fromJson(row);
  }

  Future<void> setActive(String id, {required bool active}) async {
    await _client
        .from('coupons')
        .update(<String, dynamic>{'is_active': active})
        .eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('coupons').delete().eq('id', id);
  }
}
