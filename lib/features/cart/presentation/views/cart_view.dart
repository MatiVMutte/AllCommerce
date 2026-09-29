import 'dart:async';

import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/router/return_to.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/cart/data/models/cart_item.dart';
import 'package:all_commerce/features/cart/data/models/cart_state.dart';
import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/services/whatsapp_message_builder.dart';
import 'package:all_commerce/features/orders/presentation/view_models/checkout_controller.dart';
import 'package:all_commerce/features/orders/presentation/views/order_success_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class CartView extends ConsumerStatefulWidget {
  const CartView({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<CartView> createState() => _CartViewState();
}

class _CartViewState extends ConsumerState<CartView> {
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _coupon = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _confirm(TenantModel tenant) async {
    final CartState cart = ref.read(cartProvider);
    if (ref.read(sessionProvider) == null) {
      ref.read(returnToProvider.notifier).set('/s/${widget.slug}/cart');
      unawaited(context.push('/login'));
      return;
    }
    final UserModel? profile = ref.read(currentProfileProvider).value;
    if (profile == null) {
      ref.read(returnToProvider.notifier).set('/s/${widget.slug}/cart');
      unawaited(context.push('/select-role'));
      return;
    }
    String phone = profile.phone ?? '';
    if (phone.isEmpty) {
      final String? entered = await _askPhone();
      if (entered == null || !mounted) return;
      try {
        await ref.read(authRepositoryProvider).updatePhone(profile.id, entered);
      } catch (e) {
        if (mounted) showErrorSnackBar(context, e);
        return;
      }
      ref.invalidate(currentProfileProvider);
      phone = entered;
    }
    final String coupon = _coupon.text.trim();
    final OrderModel? order = await ref
        .read(checkoutControllerProvider.notifier)
        .placeOrder(
          tenantId: tenant.id,
          items: cart.items,
          couponCode: coupon.isEmpty ? null : coupon,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
    if (!mounted) return;
    if (order == null) {
      final Object? error = ref.read(checkoutControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
      return;
    }
    final String message = buildOrderMessage(
      tenant: tenant,
      order: order,
      items: cart.items,
      customerName: profile.fullName,
      customerPhone: phone,
      couponCode: coupon.isEmpty ? null : coupon,
    );
    final Uri uri = buildWhatsAppUri(tenant.whatsapp, message);
    // The order is already saved; the success screen offers a retry button
    // if WhatsApp could not be opened (e.g. popup blocked on web).
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!mounted) return;
    ref.read(cartProvider.notifier).clear();
    context.go(
      '/s/${widget.slug}/order/${order.id}',
      extra: OrderConfirmation(order: order, whatsappUri: uri.toString()),
    );
  }

  Future<String?> _askPhone() {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Tu WhatsApp'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp',
              helperText: 'Con código de área, sin 0 ni 15',
            ),
            validator: Validators.phone,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context)
                    .pop(Validators.normalizePhone(controller.text));
              }
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<TenantModel?> tenantAsync = ref.watch(
      tenantBySlugProvider(widget.slug),
    );
    final CartState cart = ref.watch(cartProvider);
    return tenantAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stack) =>
          const Scaffold(body: Center(child: Text(AppStrings.genericError))),
      data: (TenantModel? tenant) {
        if (tenant == null) {
          return const Scaffold(
            body: Center(child: Text(AppStrings.storeNotFound)),
          );
        }
        final bool wrongStore =
            cart.tenantId != null && cart.tenantId != tenant.id;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tu pedido'),
            leading: AppBackButton(fallback: '/s/${widget.slug}'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: (cart.isEmpty || wrongStore)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text('Tu carrito está vacío'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context.go('/s/${widget.slug}'),
                          child: const Text('Ver catálogo'),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        for (final CartItem item in cart.items)
                          _CartTile(item: item),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                TextField(
                                  controller: _notes,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Notas para el local (opcional)',
                                  ),
                                ),
                                ExpansionTile(
                                  title: const Text('¿Tenés un cupón?'),
                                  tilePadding: EdgeInsets.zero,
                                  children: <Widget>[
                                    TextField(
                                      controller: _coupon,
                                      decoration: const InputDecoration(
                                        labelText: 'Código de cupón',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    const Text('Subtotal'),
                                    Text(
                                      Formatters.price(cart.subtotal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  icon: const Icon(Icons.send),
                                  label: Text(
                                    'Confirmar pedido por WhatsApp · '
                                    '${Formatters.price(cart.subtotal)}',
                                  ),
                                  onPressed:
                                      ref
                                          .watch(checkoutControllerProvider)
                                          .sending
                                      ? null
                                      : () => _confirm(tenant),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Al confirmar se guarda el pedido y se abre '
                                  'WhatsApp con el detalle para '
                                  '${tenant.name}.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _CartTile extends ConsumerWidget {
  const _CartTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: item.imageUrl == null
              ? Container(
                  color: const Color(0xFFE3E7F3),
                  child: const Icon(Icons.image_not_supported_outlined),
                )
              : CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (BuildContext context, String url, _) =>
                      const Icon(Icons.image_not_supported_outlined),
                ),
        ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => ref
                .read(cartProvider.notifier)
                .setQuantity(item.productId, item.quantity - 1),
          ),
          Text('${item.quantity}'),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => ref
                .read(cartProvider.notifier)
                .setQuantity(item.productId, item.quantity + 1),
          ),
          const Spacer(),
          Text(Formatters.price(item.lineTotal)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                ref.read(cartProvider.notifier).remove(item.productId),
          ),
        ],
      ),
    );
  }
}
