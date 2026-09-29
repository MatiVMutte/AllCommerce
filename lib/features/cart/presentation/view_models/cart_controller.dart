import 'package:all_commerce/core/storage/shared_preferences_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/features/cart/data/models/cart_item.dart';
import 'package:all_commerce/features/cart/data/models/cart_state.dart';
import 'package:all_commerce/features/cart/data/repositories/cart_storage.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Provider<CartStorage> cartStorageProvider = Provider<CartStorage>(
  (Ref ref) => CartStorage(ref.watch(sharedPreferencesProvider)),
);

enum AddResult { added, differentStore }

class CartController extends Notifier<CartState> {
  @override
  CartState build() {
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    return CartStorage(prefs).load() ?? const CartState();
  }

  void _persist() {
    ref.read(cartStorageProvider).save(state);
  }

  /// Adds [quantity] of [product]. Returns [AddResult.differentStore]
  /// without modifying state when the cart belongs to another tenant.
  AddResult add(
    ProductModel product,
    TenantModel tenant, {
    int quantity = 1,
  }) {
    if (state.tenantId != null && state.tenantId != tenant.id) {
      return AddResult.differentStore;
    }
    final List<CartItem> items = List<CartItem>.of(state.items);
    final int index =
        items.indexWhere((CartItem i) => i.productId == product.id);
    if (index >= 0) {
      items[index] =
          items[index].copyWith(quantity: items[index].quantity + quantity);
    } else {
      items.add(
        CartItem(
          productId: product.id,
          title: product.title,
          price: product.price,
          imageUrl: product.imageUrl,
          quantity: quantity,
        ),
      );
    }
    state = state.copyWith(
      tenantId: () => tenant.id,
      tenantSlug: () => tenant.slug,
      items: items,
    );
    _persist();
    return AddResult.added;
  }

  /// Empties the cart and adds the product (store-switch confirm flow).
  void replaceWith(
    ProductModel product,
    TenantModel tenant, {
    int quantity = 1,
  }) {
    state = CartState(
      tenantId: tenant.id,
      tenantSlug: tenant.slug,
      items: <CartItem>[
        CartItem(
          productId: product.id,
          title: product.title,
          price: product.price,
          imageUrl: product.imageUrl,
          quantity: quantity,
        ),
      ],
    );
    _persist();
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    state = state.copyWith(
      items: state.items
          .map(
            (CartItem i) =>
                i.productId == productId ? i.copyWith(quantity: quantity) : i,
          )
          .toList(),
    );
    _persist();
  }

  void remove(String productId) {
    final List<CartItem> items = state.items
        .where((CartItem i) => i.productId != productId)
        .toList();
    state = items.isEmpty
        ? const CartState()
        : state.copyWith(items: items);
    _persist();
  }

  void clear() {
    state = const CartState();
    _persist();
  }
}

final NotifierProvider<CartController, CartState> cartProvider =
    NotifierProvider<CartController, CartState>(CartController.new);
