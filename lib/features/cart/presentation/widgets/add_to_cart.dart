import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Adds [product] to the cart; if the cart belongs to another store, asks
/// the user to confirm replacing it.
Future<void> addToCartWithConfirm(
  BuildContext context,
  WidgetRef ref,
  ProductModel product,
  TenantModel tenant, {
  int quantity = 1,
}) async {
  final CartController cart = ref.read(cartProvider.notifier);
  final AddResult result = cart.add(product, tenant, quantity: quantity);
  if (result == AddResult.added) {
    showAppSnackBar(
      context,
      'Agregado al carrito',
      action: SnackBarAction(
        label: 'Ver',
        onPressed: () => context.push('/s/${tenant.slug}/cart'),
      ),
    );
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
    cart.replaceWith(product, tenant, quantity: quantity);
    showAppSnackBar(context, 'Agregado al carrito');
  }
}
