import 'package:all_commerce/core/constants/categories.dart';
import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/utils/text_utils.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/data/repositories/catalog_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>(
  (Ref ref) => CatalogRepository(ref.watch(supabaseClientProvider)),
);

final FutureProvider<List<TenantModel>> activeTenantsProvider =
    FutureProvider<List<TenantModel>>(
  (Ref ref) => ref.watch(tenantRepositoryProvider).listActive(),
);

final catalogProductsProvider =
    FutureProvider.family<List<ProductModel>, String>(
  (Ref ref, String tenantId) =>
      ref.watch(catalogRepositoryProvider).listActiveProducts(tenantId),
);

final productByIdProvider = FutureProvider.family<
    ProductModel?,
    ({String tenantId, String productId})>(
  (Ref ref, ({String tenantId, String productId}) key) => ref
      .watch(catalogRepositoryProvider)
      .getProduct(key.tenantId, key.productId),
);

class CatalogFilter {
  const CatalogFilter({this.query = '', this.category});

  final String query;
  final ProductCategory? category;

  CatalogFilter copyWith({
    String? query,
    ProductCategory? Function()? category,
  }) {
    return CatalogFilter(
      query: query ?? this.query,
      category: category != null ? category() : this.category,
    );
  }
}

class CatalogFilterNotifier extends Notifier<CatalogFilter> {
  CatalogFilterNotifier(this.slug);

  /// Store slug this filter belongs to.
  final String slug;

  @override
  CatalogFilter build() => const CatalogFilter();

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  /// Toggles [category] off when it's already selected.
  void setCategory(ProductCategory category) {
    state = state.copyWith(
      category: () => state.category == category ? null : category,
    );
  }

  void clear() => state = const CatalogFilter();
}

final catalogFilterProvider =
    NotifierProvider.family<CatalogFilterNotifier, CatalogFilter, String>(
  CatalogFilterNotifier.new,
);

/// Pure, widget-free catalog filtering.
List<ProductModel> applyCatalogFilter(
  List<ProductModel> products,
  CatalogFilter filter,
) {
  final String query = removeDiacritics(filter.query.trim().toLowerCase());
  return products.where((ProductModel product) {
    if (filter.category != null && product.category != filter.category!.id) {
      return false;
    }
    if (query.isEmpty) return true;
    bool matches(String? text) =>
        text != null && removeDiacritics(text.toLowerCase()).contains(query);
    return matches(product.title) ||
        matches(product.description) ||
        product.tags.any(matches);
  }).toList();
}

/// Search text for the store directory.
class StoreSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final NotifierProvider<StoreSearchNotifier, String> storeSearchProvider =
    NotifierProvider<StoreSearchNotifier, String>(StoreSearchNotifier.new);

/// Pure directory filtering (name, description, address; accent-insensitive).
List<TenantModel> filterTenants(List<TenantModel> tenants, String query) {
  final String q = removeDiacritics(query.trim().toLowerCase());
  if (q.isEmpty) return tenants;
  bool matches(String? text) =>
      text != null && removeDiacritics(text.toLowerCase()).contains(q);
  return tenants
      .where(
        (TenantModel t) =>
            matches(t.name) || matches(t.description) || matches(t.address),
      )
      .toList();
}
