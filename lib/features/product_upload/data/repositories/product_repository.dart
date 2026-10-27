import 'dart:typed_data';

import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/product_upload/data/models/product_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductRepository {
  const ProductRepository(this._client);

  final SupabaseClient _client;

  Future<ProductModel> create(ProductInput input, String tenantId) async {
    final Map<String, dynamic> row = await _client
        .from('products')
        .insert(<String, dynamic>{
          'tenant_id': tenantId,
          'title': input.title,
          'description': input.description,
          'category': input.category,
          'tags': input.tags,
          'price': input.price,
          'compare_at_price': input.compareAtPrice,
          'sku': input.sku,
          'stock': input.stock,
          'track_stock': input.trackStock,
          'is_active': true,
        })
        .select()
        .single();
    return ProductModel.fromJson(row);
  }

  Future<String> uploadImage({
    required String tenantId,
    required String productId,
    required Uint8List jpegBytes,
  }) async {
    final String path = '$tenantId/$productId.jpg';
    await _client.storage
        .from('product-images')
        .uploadBinary(
          path,
          jpegBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    // Same path on re-upload: version the URL so caches pick up the new image.
    final String url = _client.storage
        .from('product-images')
        .getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// All products of the tenant, active or not, newest first.
  Future<List<ProductModel>> listAll(String tenantId) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('products')
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
    return rows.map(ProductModel.fromJson).toList();
  }

  Future<ProductModel?> getById(String tenantId, String productId) async {
    final Map<String, dynamic>? row = await _client
        .from('products')
        .select()
        .eq('tenant_id', tenantId)
        .eq('id', productId)
        .maybeSingle();
    if (row == null) return null;
    return ProductModel.fromJson(row);
  }

  Future<ProductModel> update(
    String productId,
    String tenantId,
    ProductInput input,
  ) async {
    final Map<String, dynamic> row = await _client
        .from('products')
        .update(<String, dynamic>{
          'title': input.title,
          'description': input.description,
          'category': input.category,
          'tags': input.tags,
          'price': input.price,
          'compare_at_price': input.compareAtPrice,
          'sku': input.sku,
          'stock': input.stock,
          'track_stock': input.trackStock,
        })
        .eq('id', productId)
        .eq('tenant_id', tenantId)
        .select()
        .single();
    return ProductModel.fromJson(row);
  }

  Future<void> setActive(
    String productId,
    String tenantId,
    bool isActive,
  ) async {
    await _client
        .from('products')
        .update(<String, dynamic>{'is_active': isActive})
        .eq('id', productId)
        .eq('tenant_id', tenantId);
  }

  Future<void> setStock(
    String productId,
    String tenantId, {
    required int stock,
    required bool trackStock,
  }) async {
    await _client
        .from('products')
        .update(<String, dynamic>{
          'stock': stock,
          'track_stock': trackStock,
        })
        .eq('id', productId)
        .eq('tenant_id', tenantId);
  }

  Future<void> delete(String productId, String tenantId) async {
    await _client
        .from('products')
        .delete()
        .eq('id', productId)
        .eq('tenant_id', tenantId);
    try {
      await _client.storage.from('product-images').remove(<String>[
        '$tenantId/$productId.jpg',
      ]);
    } catch (_) {
      // Missing image is fine; storage errors are non-blocking.
    }
  }

  Future<void> setImageUrl(String productId, String url) async {
    await _client
        .from('products')
        .update(<String, dynamic>{'image_url': url})
        .eq('id', productId);
  }
}
