import 'package:all_commerce/core/utils/text_utils.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/product_upload_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every product of the tenant (active or not). Exposed as a notifier
/// so the inventory can apply optimistic updates.
class OwnerProductsNotifier extends AsyncNotifier<List<ProductModel>> {
  OwnerProductsNotifier(this.tenantId);

  final String tenantId;

  @override
  Future<List<ProductModel>> build() =>
      ref.watch(productRepositoryProvider).listAll(tenantId);

  /// Locally replaces the list (optimistic update/rollback). The
  /// authoritative refetch still happens through `ref.invalidate`.
  void replace(List<ProductModel> list) =>
      state = AsyncData<List<ProductModel>>(list);
}

final ownerProductsProvider = AsyncNotifierProvider.autoDispose
    .family<OwnerProductsNotifier, List<ProductModel>, String>(
      OwnerProductsNotifier.new,
    );

/// Resolves a product restricted to the logged-in owner's tenant.
/// Returns null for unknown ids or ids of other tenants.
final ownerProductProvider = FutureProvider.autoDispose
    .family<ProductModel?, String>((Ref ref, String productId) async {
      final String? tenantId = await ref
          .watch(currentProfileProvider.future)
          .then((profile) => profile?.tenantId);
      if (tenantId == null) return null;
      return ref.watch(productRepositoryProvider).getById(tenantId, productId);
    });

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
      busyProductId: busyProductId != null
          ? busyProductId()
          : this.busyProductId,
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
    }, optimistic: product.copyWith(isActive: !product.isActive));
  }

  Future<bool> updateStock(
    ProductModel product, {
    required int stock,
    required bool trackStock,
  }) async {
    final int normalized = stock < 0 ? 0 : stock;
    return _run(product, (String id, String tenantId) {
      return ref
          .read(productRepositoryProvider)
          .setStock(id, tenantId, stock: normalized, trackStock: trackStock);
    }, optimistic: product.copyWith(stock: normalized, trackStock: trackStock));
  }

  Future<bool> delete(ProductModel product) async {
    return _run(product, (String id, String tenantId) {
      return ref.read(productRepositoryProvider).delete(id, tenantId);
    }, deleted: true);
  }

  List<ProductModel>? _list(String tenantId) =>
      ref.read(ownerProductsProvider(tenantId)).value;

  void _setList(String tenantId, List<ProductModel> list) {
    ref.read(ownerProductsProvider(tenantId).notifier).replace(list);
  }

  Future<bool> _run(
    ProductModel product,
    Future<void> Function(String id, String tenantId) action, {
    ProductModel? optimistic,
    bool deleted = false,
  }) async {
    state = state.copyWith(busyProductId: () => product.id, error: () => null);
    final List<ProductModel>? before = _list(product.tenantId);
    if (before != null && (optimistic != null || deleted)) {
      _setList(product.tenantId, <ProductModel>[
        for (final ProductModel p in before)
          if (p.id != product.id) p else ?optimistic,
      ]);
    }
    try {
      await action(product.id, product.tenantId);
      state = state.copyWith(busyProductId: () => null);
      ref.invalidate(ownerProductsProvider(product.tenantId));
      ref.invalidate(catalogProductsProvider(product.tenantId));
      return true;
    } catch (e) {
      if (before != null) _setList(product.tenantId, before);
      state = state.copyWith(busyProductId: () => null, error: () => e);
      return false;
    }
  }
}

final ownerInventoryControllerProvider =
    NotifierProvider.autoDispose<OwnerInventoryController, OwnerInventoryState>(
      OwnerInventoryController.new,
    );

/// Product selected in the wide master–detail layout ('new' = blank form).
class SelectedOwnerProductNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedOwnerProductProvider =
    NotifierProvider<SelectedOwnerProductNotifier, String?>(
      SelectedOwnerProductNotifier.new,
    );
