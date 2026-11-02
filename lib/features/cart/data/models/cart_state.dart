import 'package:all_commerce/features/cart/data/models/cart_item.dart';

class CartState {
  const CartState({
    this.tenantId,
    this.tenantSlug,
    this.items = const <CartItem>[],
    this.couponCode,
  });

  final String? tenantId;
  final String? tenantSlug;
  final List<CartItem> items;

  /// Applied coupon code, kept so it survives leaving the cart screen.
  /// Re-validated against the server before checkout.
  final String? couponCode;

  double get itemCount =>
      items.fold(0, (double sum, CartItem i) => sum + i.quantity);

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
      couponCode: json['coupon_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tenant_id': tenantId,
      'tenant_slug': tenantSlug,
      'items': items.map((CartItem i) => i.toJson()).toList(),
      'coupon_code': couponCode,
    };
  }

  CartState copyWith({
    String? Function()? tenantId,
    String? Function()? tenantSlug,
    List<CartItem>? items,
    String? Function()? couponCode,
  }) {
    return CartState(
      tenantId: tenantId != null ? tenantId() : this.tenantId,
      tenantSlug: tenantSlug != null ? tenantSlug() : this.tenantSlug,
      items: items ?? this.items,
      couponCode: couponCode != null ? couponCode() : this.couponCode,
    );
  }
}
