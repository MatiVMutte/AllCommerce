import 'package:all_commerce/features/cart/data/models/cart_item.dart';

class CartState {
  const CartState({
    this.tenantId,
    this.tenantSlug,
    this.items = const <CartItem>[],
  });

  final String? tenantId;
  final String? tenantSlug;
  final List<CartItem> items;

  int get itemCount =>
      items.fold(0, (int sum, CartItem i) => sum + i.quantity);

  double get subtotal =>
      items.fold(0, (double sum, CartItem i) => sum + i.lineTotal);

  bool get isEmpty => items.isEmpty;

  factory CartState.fromJson(Map<String, dynamic> json) {
    return CartState(
      tenantId: json['tenant_id'] as String?,
      tenantSlug: json['tenant_slug'] as String?,
      items: (json['items'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic i) => CartItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tenant_id': tenantId,
      'tenant_slug': tenantSlug,
      'items': items.map((CartItem i) => i.toJson()).toList(),
    };
  }

  CartState copyWith({
    String? Function()? tenantId,
    String? Function()? tenantSlug,
    List<CartItem>? items,
  }) {
    return CartState(
      tenantId: tenantId != null ? tenantId() : this.tenantId,
      tenantSlug: tenantSlug != null ? tenantSlug() : this.tenantSlug,
      items: items ?? this.items,
    );
  }
}
