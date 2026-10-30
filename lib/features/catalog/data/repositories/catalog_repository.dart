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

  Future<ProductModel?> getProduct(String tenantId, String productId) async {
    final Map<String, dynamic>? row = await _client
        .from('products')
        .select()
        .eq('tenant_id', tenantId)
        .eq('id', productId)
        .maybeSingle();
    if (row == null) return null;
    return ProductModel.fromJson(row);
  }

  /// All on-sale products across active stores (compare_at_price > price).
  Future<List<GlobalProductHit>> onSaleProducts({int limit = 60}) async {
    final List<dynamic> rows = await _client
        .from('products')
        .select(
          'id, tenant_id, title, description, category, price, '
          'compare_at_price, image_url, stock, track_stock, '
          'tenants!inner(slug,name,logo_url,primary_color,is_open,is_active)',
        )
        .eq('is_active', true)
        .eq('tenants.is_active', true)
        .gt('compare_at_price', 0)
        .order('updated_at', ascending: false)
        .limit(limit);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(GlobalProductHit.fromProductRow)
        .where((GlobalProductHit h) => h.isOnSale)
        .toList();
  }

  Future<List<GlobalProductHit>> searchPublicProducts(
    String query, {
    int limit = 16,
  }) async {
    final String q = query.trim();
    if (q.length < 2) return const <GlobalProductHit>[];
    final List<dynamic> rows = await _client.rpc<List<dynamic>>(
      'search_public_products',
      params: <String, dynamic>{'p_query': q, 'p_limit': limit},
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

  /// Maps a `products` row joined with `tenants` (!inner select).
  factory GlobalProductHit.fromProductRow(Map<String, dynamic> json) {
    final Map<String, dynamic> t =
        (json['tenants'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return GlobalProductHit(
      productId: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: (json['category'] as String?) ?? '',
      price: num.parse(json['price'].toString()).toDouble(),
      compareAtPrice: json['compare_at_price'] == null
          ? null
          : num.parse(json['compare_at_price'].toString()).toDouble(),
      imageUrl: json['image_url'] as String?,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      trackStock: (json['track_stock'] as bool?) ?? false,
      tenantSlug: (t['slug'] as String?) ?? '',
      tenantName: (t['name'] as String?) ?? '',
      tenantLogoUrl: t['logo_url'] as String?,
      tenantPrimaryColor: (t['primary_color'] as String?) ?? '',
      tenantIsOpen: (t['is_open'] as bool?) ?? false,
    );
  }

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
      tenantPrimaryColor: json['tenant_primary_color'] as String? ?? '#0052FF',
      tenantIsOpen: json['tenant_is_open'] as bool? ?? true,
    );
  }
}
