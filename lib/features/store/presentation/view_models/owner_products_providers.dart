import 'package:all_commerce/core/utils/text_utils.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/product_upload_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every product of the tenant (active or not).
final ownerProductsProvider =
    FutureProvider.autoDispose.family<List<ProductModel>, String>(
  (Ref ref, String tenantId) =>
      ref.watch(productRepositoryProvider).listAll(tenantId),
);

/// Resolves a product restricted to the logged-in owner's tenant.
/// Returns null for unknown ids or ids of other tenants.
final ownerProductProvider =
    FutureProvider.autoDispose.family<ProductModel?, String>(
  (Ref ref, String productId) async {
    final String? tenantId =
        await ref.watch(currentProfileProvider.future).then(
              (profile) => profile?.tenantId,
            );
    if (tenantId == null) return null;
    return ref
        .watch(productRepositoryProvider)
        .getById(tenantId, productId);
  },
);

enum OwnerFilter { all, active, paused }

/// Search text for the inventory list.
class OwnerProductQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final ownerProductQueryProvider =
    NotifierProvider.autoDispose<OwnerProductQueryNotifier, String>(
  OwnerProductQueryNotifier.new,
);

/// Active/paused filter for the inventory list.
class OwnerFilterNotifier extends Notifier<OwnerFilter> {
  @override
  OwnerFilter build() => OwnerFilter.all;

  void setFilter(OwnerFilter filter) => state = filter;
}

final ownerFilterProvider =
    NotifierProvider.autoDispose<OwnerFilterNotifier, OwnerFilter>(
  OwnerFilterNotifier.new,
);

/// Pure inventory filtering: accent-insensitive match on title/sku/tags
/// plus the active/paused filter.
List<ProductModel> filterOwnerProducts(
  List<ProductModel> products, {
  String query = '',
  OwnerFilter filter = OwnerFilter.all,
}) {
  final String q = removeDiacritics(query.trim().toLowerCase());
  return products.where((ProductModel product) {
    if (filter == OwnerFilter.active && !product.isActive) return false;
    if (filter == OwnerFilter.paused && product.isActive) return false;
    if (q.isEmpty) return true;
    bool matches(String? text) =>
        text != null && removeDiacritics(text.toLowerCase()).contains(q);
    return matches(product.title) ||
        matches(product.sku) ||
        product.tags.any(matches);
  }).toList();
}

class OwnerInventoryState {
  const OwnerInventoryState({this.busyProductId, this.error});

  final String? busyProductId;
  final Object? error;

  OwnerInventoryState copyWith({
    String? Function()? busyProductId,
    Object? Function()? error,
  }) {
    return OwnerInventoryState(
      busyProductId:
          busyProductId != null ? busyProductId() : this.busyProductId,
      error: error != null ? error() : this.error,
    );
  }
}

class OwnerInventoryController extends Notifier<OwnerInventoryState> {
  @override
  OwnerInventoryState build() => const OwnerInventoryState();

  Future<bool> toggleActive(ProductModel product) async {
    return _run(product, (String id, String tenantId) {
      return ref
          .read(productRepositoryProvider)
          .setActive(id, tenantId, !product.isActive);
    });
  }

  Future<bool> delete(ProductModel product) async {
    return _run(product, (String id, String tenantId) {
      return ref
          .read(productRepositoryProvider)
          .delete(id, tenantId);
    });
  }

  Future<bool> _run(
    ProductModel product,
    Future<void> Function(String id, String tenantId) action,
  ) async {
    state = state.copyWith(
      busyProductId: () => product.id,
      error: () => null,
    );
    try {
      await action(product.id, product.tenantId);
      state = state.copyWith(busyProductId: () => null);
      ref.invalidate(ownerProductsProvider(product.tenantId));
      ref.invalidate(catalogProductsProvider(product.tenantId));
      return true;
    } catch (e) {
      state = state.copyWith(busyProductId: () => null, error: () => e);
      return false;
    }
  }
}

final ownerInventoryControllerProvider = NotifierProvider.autoDispose<
    OwnerInventoryController, OwnerInventoryState>(
  OwnerInventoryController.new,
);
