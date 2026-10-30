import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adds [product] to the cart; if the cart belongs to another store, asks
/// the user to confirm replacing it.
Future<void> addToCartWithConfirm(
  BuildContext context,
  WidgetRef ref,
  ProductModel product,
  TenantModel tenant, {
  int quantity = 1,
  String? variant,
}) async {
  if (product.isOutOfStock) {
    showAppSnackBar(context, 'Este producto está agotado', isError: true);
    return;
  }
  final CartController cart = ref.read(cartProvider.notifier);
  if (product.trackStock) {
    final int existingQty = ref
        .read(cartProvider)
        .items
        .where((i) => i.productId == product.id)
        .fold<int>(0, (int sum, i) => sum + i.quantity);
    if (existingQty + quantity > product.stock) {
      showAppSnackBar(
        context,
        'Solo quedan ${product.stock} unidades disponibles',
        isError: true,
      );
      return;
    }
  }
  final AddResult result = cart.add(
    product,
    tenant,
    quantity: quantity,
    variant: variant,
  );
  if (result == AddResult.added) {
    return;
  }
  final bool? replace = await showAppConfirmSheet(
    context,
    title: 'Carrito de otro local',
    message:
        'Tu carrito tiene productos de otro local. ¿Vaciarlo y agregar este?',
    confirmLabel: 'Vaciar y agregar',
  );
  if (replace == true && context.mounted) {
    cart.replaceWith(product, tenant, quantity: quantity, variant: variant);
  }
}
