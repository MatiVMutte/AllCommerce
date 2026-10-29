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

  Future<List<GlobalProductHit>> searchPublicProducts(
    String query, {
    int limit = 16,
  }) async {
    final String q = query.trim();
    if (q.length < 2) return const <GlobalProductHit>[];
    final List<dynamic> rows = await _client.rpc<List<dynamic>>(
      'search_public_products',
      params: <String, dynamic>{
        'p_query': q,
        'p_limit': limit,
      },
    );
    return rows
        .whereType<Map<String, dynamic>>()
        .map(GlobalProductHit.fromJson)
        .toList();
  }
}

/// Product search hit across all active stores for the global directory search.
class GlobalProductHit {
  const GlobalProductHit({
    required this.productId,
    required this.tenantId,
    required this.title,
    this.description,
    required this.category,
    required this.price,
    this.compareAtPrice,
    this.imageUrl,
    required this.stock,
    required this.trackStock,
    required this.tenantSlug,
    required this.tenantName,
    this.tenantLogoUrl,
    required this.tenantPrimaryColor,
    required this.tenantIsOpen,
  });

  final String productId;
  final String tenantId;
  final String title;
  final String? description;
  final String category;
  final double price;
  final double? compareAtPrice;
  final String? imageUrl;
  final int stock;
  final bool trackStock;
  final String tenantSlug;
  final String tenantName;
  final String? tenantLogoUrl;
  final String tenantPrimaryColor;
  final bool tenantIsOpen;

  bool get isOnSale =>
      compareAtPrice != null && compareAtPrice! > price && price > 0;

  factory GlobalProductHit.fromJson(Map<String, dynamic> json) {
    final Object? rawCompare = json['compare_at_price'];
    final double? parsedCompare = rawCompare == null
        ? null
        : num.tryParse(rawCompare.toString())?.toDouble();
    return GlobalProductHit(
      productId: json['product_id'] as String,
      tenantId: json['tenant_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'other',
      price: num.parse(json['price'].toString()).toDouble(),
      compareAtPrice: parsedCompare,
      imageUrl: json['image_url'] as String?,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      trackStock: json['track_stock'] as bool? ?? false,
      tenantSlug: json['tenant_slug'] as String,
      tenantName: json['tenant_name'] as String,
      tenantLogoUrl: json['tenant_logo_url'] as String?,
      tenantPrimaryColor:
          json['tenant_primary_color'] as String? ?? '#0052FF',
      tenantIsOpen: json['tenant_is_open'] as bool? ?? true,
    );
  }
}
