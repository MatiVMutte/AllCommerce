import 'package:all_commerce/features/cart/data/models/cart_item.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/repositories/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CheckoutState {
  const CheckoutState({this.sending = false, this.order, this.error});

  final bool sending;
  final OrderModel? order;
  final Object? error;
}

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutState();

  Future<OrderModel?> placeOrder({
    required String tenantId,
    required List<CartItem> items,
    String? couponCode,
    String? notes,
  }) async {
    state = const CheckoutState(sending: true);
    try {
      final OrderModel order =
          await ref.read(orderRepositoryProvider).placeOrder(
                tenantId: tenantId,
                items: items,
                couponCode: couponCode,
                notes: notes,
              );
      state = CheckoutState(order: order);
      return order;
    } catch (e) {
      state = CheckoutState(error: e);
      return null;
    }
  }
}

final checkoutControllerProvider =
    NotifierProvider.autoDispose<CheckoutController, CheckoutState>(
  CheckoutController.new,
);
