import 'dart:async';

import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/constants/delivery_method.dart';
import 'package:all_commerce/core/constants/payment_method.dart';
import 'package:all_commerce/core/router/return_to.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/utils/validators.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/app_card.dart';
import 'package:all_commerce/core/widgets/app_network_image.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/quantity_stepper.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/cart/data/models/cart_item.dart';
import 'package:all_commerce/features/cart/data/models/cart_state.dart';
import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/repositories/order_repository.dart';
import 'package:all_commerce/features/orders/data/services/whatsapp_message_builder.dart';
import 'package:all_commerce/features/orders/presentation/view_models/checkout_controller.dart';
import 'package:all_commerce/features/orders/presentation/views/order_success_view.dart';
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
  String? _appliedCode;
  int? _appliedPercent;
  String? _couponError;
  bool _checkingCoupon = false;

  @override
  void dispose() {
    _notes.dispose();
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon(TenantModel tenant) async {
    final String code = _coupon.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _checkingCoupon = true;
      _couponError = null;
    });
    try {
      final int? pct = await ref
          .read(orderRepositoryProvider)
          .validateCoupon(tenant.id, code);
      if (!mounted) return;
      setState(() {
        _checkingCoupon = false;
        if (pct == null) {
          _couponError = 'Cupón no válido o inactivo';
        } else {
          _appliedCode = code.toUpperCase();
          _appliedPercent = pct;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingCoupon = false;
          _couponError = 'No pudimos validar el cupón';
        });
      }
    }
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
    final String coupon = _appliedCode ?? _coupon.text.trim();
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
    final AppTokens tokens = context.tokens;
    final AsyncValue<TenantModel?> tenantAsync = ref.watch(
      tenantBySlugProvider(widget.slug),
    );
    final CartState cart = ref.watch(cartProvider);
    return tenantAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stack) => Scaffold(
        body: AppErrorState(
          onRetry: () => ref.invalidate(tenantBySlugProvider(widget.slug)),
        ),
      ),
      data: (TenantModel? tenant) {
        if (tenant == null) {
          return Scaffold(
            body: AppEmptyState(
              icon: Icons.storefront_outlined,
              title: AppStrings.storeNotFound,
              actionLabel: AppStrings.backToHome,
              onAction: () => context.go('/'),
            ),
          );
        }
        final bool wrongStore =
            cart.tenantId != null && cart.tenantId != tenant.id;
        final bool empty = cart.isEmpty || wrongStore;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tu pedido'),
            leading: AppBackButton(fallback: '/s/${widget.slug}'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: empty
                  ? AppEmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Tu carrito está vacío',
                      subtitle: 'Agregá productos de ${tenant.name}',
                      actionLabel: 'Ver catálogo',
                      onAction: () => context.go('/s/${widget.slug}'),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: <Widget>[
                        if (!tenant.isOpen)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: tokens.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: tokens.warning.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.schedule_rounded,
                                  color: tokens.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tenant.openingHours != null &&
                                            tenant.openingHours!
                                                .trim()
                                                .isNotEmpty
                                        ? '${tenant.name} figura como cerrado ahora (${tenant.openingHours}). Podés enviar el pedido igual y lo verán cuando abran.'
                                        : '${tenant.name} figura como cerrado ahora. Podés enviar el pedido igual y lo verán cuando abran.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            tenant.name,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        for (final CartItem item in cart.items)
                          _CartTile(item: item),
                        const SizedBox(height: 8),
                        AppCard(
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
                                  if (_appliedCode != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.success.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: tokens.success,
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Icon(
                                            Icons.local_offer_rounded,
                                            color: tokens.success,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '$_appliedCode · '
                                              '−$_appliedPercent%',
                                              style: TextStyle(
                                                color: tokens.success,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Quitar cupón',
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                            ),
                                            onPressed: () => setState(() {
                                              _appliedCode = null;
                                              _appliedPercent = null;
                                              _coupon.clear();
                                            }),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        TextField(
                                          controller: _coupon,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          onSubmitted: (_) =>
                                              _applyCoupon(tenant),
                                          decoration: InputDecoration(
                                            labelText: 'Código de cupón',
                                            errorText: _couponError,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        FilledButton.icon(
                                          icon: _checkingCoupon
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.local_offer_rounded,
                                                ),
                                          label: Text(
                                            _checkingCoupon
                                                ? 'Validando…'
                                                : 'Aplicar cupón',
                                          ),
                                          onPressed: _checkingCoupon
                                              ? null
                                              : () => _applyCoupon(tenant),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DeliverySection(tenant: tenant),
                        const SizedBox(height: 16),
                        _PaymentSection(tenant: tenant),
                      ],
                    ),
            ),
          ),
          bottomNavigationBar: empty
              ? null
              : SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      border: Border(top: BorderSide(color: tokens.border)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Subtotal',
                              style: TextStyle(color: tokens.textSecondary),
                            ),
                            Text(Formatters.price(cart.subtotal)),
                          ],
                        ),
                        if (_appliedPercent != null) ...<Widget>[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Descuento ($_appliedCode)',
                                style: TextStyle(color: tokens.success),
                              ),
                              Text(
                                '−${Formatters.price(cart.subtotal * _appliedPercent! / 100)}',
                                style: TextStyle(
                                  color: tokens.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              Formatters.price(
                                cart.subtotal *
                                    (1 - (_appliedPercent ?? 0) / 100),
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.chat_bubble_rounded),
                            label: const Text('Confirmar por WhatsApp'),
                            onPressed:
                                ref.watch(checkoutControllerProvider).sending
                                ? null
                                : () => _confirm(tenant),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Se guarda el pedido y se abre WhatsApp '
                          'con el detalle para ${tenant.name}.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
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

class _DeliverySection extends ConsumerWidget {
  const _DeliverySection({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final CheckoutState checkoutState = ref.watch(checkoutControllerProvider);
    final DeliveryMethod method = checkoutState.deliveryMethod;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '¿Cómo querés recibirlo?',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _ChoiceChip(
                label: DeliveryMethod.pickup.label,
                selected: method == DeliveryMethod.pickup,
                onTap: () => ref
                    .read(checkoutControllerProvider.notifier)
                    .setDelivery(DeliveryMethod.pickup),
              ),
              const SizedBox(width: 8),
              _ChoiceChip(
                label: DeliveryMethod.delivery.label,
                selected: method == DeliveryMethod.delivery,
                onTap: () => ref
                    .read(checkoutControllerProvider.notifier)
                    .setDelivery(DeliveryMethod.delivery),
              ),
            ],
          ),
          if (method == DeliveryMethod.delivery) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              onChanged: (String value) => ref
                  .read(checkoutControllerProvider.notifier)
                  .setDelivery(DeliveryMethod.delivery, address: value),
              decoration: const InputDecoration(
                labelText: 'Dirección de envío',
                hintText: 'Calle, número, piso, depto',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentSection extends ConsumerWidget {
  const _PaymentSection({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final CheckoutState checkoutState = ref.watch(checkoutControllerProvider);
    final PaymentMethod method = checkoutState.paymentMethod;

    final List<PaymentMethodOption> options = <PaymentMethodOption>[
      if (tenant.acceptsCash)
        PaymentMethodOption(PaymentMethod.cash, PaymentMethod.cash.label),
      if (tenant.transferAlias?.isNotEmpty == true)
        PaymentMethodOption(
          PaymentMethod.transfer,
          '${PaymentMethod.transfer.label} · ${tenant.transferAlias}',
        ),
      if (tenant.mercadoPagoLink?.isNotEmpty == true)
        PaymentMethodOption(
          PaymentMethod.mercadoPago,
          PaymentMethod.mercadoPago.label,
        ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '¿Cómo vas a pagar?',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final PaymentMethodOption opt in options)
                _ChoiceChip(
                  label: opt.label,
                  selected: method == opt.method,
                  onTap: () => ref
                      .read(checkoutControllerProvider.notifier)
                      .setPayment(opt.method),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _paymentHint(tenant, method),
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _paymentHint(TenantModel tenant, PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Pagás al retirar o cuando te lo entreguen.';
      case PaymentMethod.transfer:
        return 'Alias/CBU: ${tenant.transferAlias}. Envianos el comprobante por WhatsApp.';
      case PaymentMethod.mercadoPago:
        return 'Te vamos a mandar el link de pago por WhatsApp.';
    }
  }
}

class PaymentMethodOption {
  const PaymentMethodOption(this.method, this.label);

  final PaymentMethod method;
  final String label;
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color bg = selected
        ? Theme.of(context).colorScheme.primaryContainer
        : tokens.surfaceMuted;
    final Color fg = selected
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : tokens.textSecondary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: fg,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _CartTile extends ConsumerWidget {
  const _CartTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    return Dismissible(
      key: ValueKey<String>(item.productId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          ref.read(cartProvider.notifier).remove(item.productId),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: tokens.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 64,
                height: 64,
                child: item.imageUrl == null
                    ? Container(
                        color: tokens.surfaceMuted,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: tokens.textTertiary,
                        ),
                      )
                    : AppNetworkImage(
                        imageUrl: item.imageUrl!,
                        placeholder: Container(color: tokens.surfaceMuted),
                        errorBuilder: (_) => Container(
                          color: tokens.surfaceMuted,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: tokens.textTertiary,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.price(item.price),
                    style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                QuantityStepper(
                  dense: true,
                  quantity: item.quantity,
                  onChanged: (int qty) => ref
                      .read(cartProvider.notifier)
                      .setQuantity(item.productId, qty),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.price(item.lineTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
