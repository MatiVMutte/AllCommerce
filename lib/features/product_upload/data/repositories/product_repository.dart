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
          'sku': input.sku,
          'stock': input.stock,
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
    await _client.storage.from('product-images').uploadBinary(
          path,
          jpegBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return _client.storage.from('product-images').getPublicUrl(path);
  }

  Future<void> setImageUrl(String productId, String url) async {
    await _client
        .from('products')
        .update(<String, dynamic>{'image_url': url})
        .eq('id', productId);
  }
}
