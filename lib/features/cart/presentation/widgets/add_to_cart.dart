import 'package:all_commerce/core/tenant/tenant_model.dart';
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
  final AddResult result =
      cart.add(product, tenant, quantity: quantity);
  if (result == AddResult.added) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Agregado al carrito'),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => context.go('/s/${tenant.slug}/cart'),
        ),
      ),
    );
    return;
  }
  final bool? replace = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Carrito de otro local'),
      content: const Text(
        'Tu carrito tiene productos de otro local. '
        '¿Vaciarlo y agregar este?',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Vaciar y agregar'),
        ),
      ],
    ),
  );
  if (replace == true && context.mounted) {
    cart.replaceWith(product, tenant, quantity: quantity);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Agregado al carrito')),
    );
  }
}
