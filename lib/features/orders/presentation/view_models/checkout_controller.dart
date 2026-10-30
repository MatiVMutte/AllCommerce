import 'dart:async';

import 'package:all_commerce/core/constants/delivery_method.dart';
import 'package:all_commerce/core/constants/payment_method.dart';
import 'package:all_commerce/features/cart/data/models/cart_item.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/repositories/order_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CheckoutState {
  const CheckoutState({
    this.sending = false,
    this.order,
    this.error,
    this.deliveryMethod = DeliveryMethod.pickup,
    this.deliveryAddress,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentNotes,
  });

  final bool sending;
  final OrderModel? order;
  final Object? error;
  final DeliveryMethod deliveryMethod;
  final String? deliveryAddress;
  final PaymentMethod paymentMethod;
  final String? paymentNotes;

  CheckoutState copyWith({
    bool? sending,
    OrderModel? order,
    Object? error,
    DeliveryMethod? deliveryMethod,
    String? Function()? deliveryAddress,
    PaymentMethod? paymentMethod,
    String? Function()? paymentNotes,
  }) {
    return CheckoutState(
      sending: sending ?? this.sending,
      order: order ?? this.order,
      error: error ?? this.error,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      deliveryAddress: deliveryAddress != null
          ? deliveryAddress()
          : this.deliveryAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentNotes: paymentNotes != null ? paymentNotes() : this.paymentNotes,
    );
  }
}

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  void setDelivery(DeliveryMethod method, {String? address}) {
    state = state.copyWith(
      deliveryMethod: method,
      deliveryAddress: () => address,
    );
  }

  void setPayment(PaymentMethod method, {String? notes}) {
    state = state.copyWith(paymentMethod: method, paymentNotes: () => notes);
  }

  Future<OrderModel?> placeOrder({
    required String tenantId,
    required List<CartItem> items,
    String? couponCode,
    String? notes,
  }) async {
    state = state.copyWith(sending: true);
    try {
      final OrderModel order = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            tenantId: tenantId,
            items: items,
            couponCode: couponCode,
            notes: notes,
            deliveryMethod: state.deliveryMethod,
            deliveryAddress: state.deliveryAddress,
            paymentMethod: state.paymentMethod,
            paymentNotes: state.paymentNotes,
          );
      _notifyOwner(order);
      state = state.copyWith(sending: false, order: order);
      return order;
    } catch (e) {
      debugPrint('placeOrder failed: $e');
      state = state.copyWith(sending: false, error: e);
      return null;
    }
  }

  void _notifyOwner(OrderModel order) {
    try {
      unawaited(ref.read(orderRepositoryProvider).notifyOwner(order));
    } catch (_) {
      // Best-effort notification.
    }
  }
}

final checkoutControllerProvider =
    NotifierProvider.autoDispose<CheckoutController, CheckoutState>(
      CheckoutController.new,
    );
