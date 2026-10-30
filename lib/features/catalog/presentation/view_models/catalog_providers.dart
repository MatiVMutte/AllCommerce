import 'package:all_commerce/core/constants/categories.dart';
import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/utils/text_utils.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/data/repositories/catalog_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>(
      (Ref ref) => CatalogRepository(ref.watch(supabaseClientProvider)),
    );

final catalogProductsProvider =
    FutureProvider.family<List<ProductModel>, String>(
      (Ref ref, String tenantId) =>
          ref.watch(catalogRepositoryProvider).listActiveProducts(tenantId),
    );

final productByIdProvider =
    FutureProvider.family<ProductModel?, ({String tenantId, String productId})>(
      (Ref ref, ({String tenantId, String productId}) key) => ref
          .watch(catalogRepositoryProvider)
          .getProduct(key.tenantId, key.productId),
    );

class CatalogFilter {
  const CatalogFilter({
    this.query = '',
    this.category,
    this.onlyOnSale = false,
  });

  final String query;
  final ProductCategory? category;
  final bool onlyOnSale;

  CatalogFilter copyWith({
    String? query,
    ProductCategory? Function()? category,
    bool? onlyOnSale,
  }) {
    return CatalogFilter(
      query: query ?? this.query,
      category: category != null ? category() : this.category,
      onlyOnSale: onlyOnSale ?? this.onlyOnSale,
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
      onlyOnSale: false,
    );
  }

  void toggleOnSale() {
    state = state.copyWith(onlyOnSale: !state.onlyOnSale, category: () => null);
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
    if (filter.onlyOnSale && !product.isOnSale) {
      return false;
    }
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

final globalProductSearchProvider =
    FutureProvider.family<List<GlobalProductHit>, String>((
      Ref ref,
      String rawQuery,
    ) async {
      final String q = rawQuery.trim();
      if (q.length < 2) return const <GlobalProductHit>[];
      return ref.watch(catalogRepositoryProvider).searchPublicProducts(q);
    });

/// All products on sale across active stores (Ofertas tab).
final onSaleProductsProvider =
    FutureProvider.autoDispose<List<GlobalProductHit>>(
      (Ref ref) => ref.watch(catalogRepositoryProvider).onSaleProducts(),
    );

/// Pure directory filtering (name, description, address; accent-insensitive).
List<TenantModel> filterTenants(List<TenantModel> tenants, String query) {
  final String q = removeDiacritics(query.trim().toLowerCase());
  if (q.isEmpty) return tenants;
  bool matches(String? text) =>
      text != null && removeDiacritics(text.toLowerCase()).contains(q);
  return tenants
      .where(
        (TenantModel t) =>
            matches(t.name) ||
            matches(t.description) ||
            matches(t.address) ||
            matches(t.zone),
      )
      .toList();
}
