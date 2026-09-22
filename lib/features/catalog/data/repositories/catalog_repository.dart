import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogRepository {
  const CatalogRepository(this._client);

  final SupabaseClient _client;

  Future<List<ProductModel>> listActiveProducts(String tenantId) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('products')
        .select()
        .eq('tenant_id', tenantId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return rows.map(ProductModel.fromJson).toList();
  }

  Future<ProductModel?> getProduct(
    String tenantId,
    String productId,
  ) async {
    final Map<String, dynamic>? row = await _client
        .from('products')
        .select()
        .eq('tenant_id', tenantId)
        .eq('id', productId)
        .maybeSingle();
    if (row == null) return null;
    return ProductModel.fromJson(row);
  }
}
