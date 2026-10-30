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
          'wholesale_price': input.wholesalePrice,
          'wholesale_min_qty': input.wholesaleMinQty,
          'sku': input.sku,
          'variants': input.variants,
          'unit': input.unit,
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
    // Unique path per upload: kept gallery URLs never get overwritten.
    final String path =
        '$tenantId/$productId-'
        '${DateTime.now().microsecondsSinceEpoch}.jpg';
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
    return _client.storage.from('product-images').getPublicUrl(path);
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
          'wholesale_price': input.wholesalePrice,
          'wholesale_min_qty': input.wholesaleMinQty,
          'sku': input.sku,
          'variants': input.variants,
          'unit': input.unit,
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
    required double stock,
    required bool trackStock,
  }) async {
    await _client
        .from('products')
        .update(<String, dynamic>{'stock': stock, 'track_stock': trackStock})
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
      final List<FileObject> files = await _client.storage
          .from('product-images')
          .list(path: tenantId);
      final List<String> paths = files
          .where((FileObject f) => f.name.startsWith(productId))
          .map((FileObject f) => '$tenantId/${f.name}')
          .toList();
      if (paths.isNotEmpty) {
        await _client.storage.from('product-images').remove(paths);
      }
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

  /// Persists the ordered gallery; the first URL is also the cover image.
  Future<void> setGallery(String productId, List<String> urls) async {
    await _client
        .from('products')
        .update(<String, dynamic>{
          'image_url': urls.isEmpty ? null : urls.first,
          'image_urls': urls,
        })
        .eq('id', productId);
  }
}
