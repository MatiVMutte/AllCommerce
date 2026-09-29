import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/utils/text_utils.dart';
import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/repositories/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ownerOrdersProvider =
    FutureProvider.autoDispose.family<List<OrderModel>, String>(
  (Ref ref, String tenantId) =>
      ref.watch(orderRepositoryProvider).listByTenant(tenantId),
);

final orderItemsProvider =
    FutureProvider.autoDispose.family<List<OrderItemModel>, String>(
  (Ref ref, String orderId) =>
      ref.watch(orderRepositoryProvider).listItems(orderId),
);

/// null means "all statuses".
class OwnerOrderStatusFilterNotifier extends Notifier<OrderStatus?> {
  @override
  OrderStatus? build() => null;

  void select(OrderStatus? status) => state = status;
}

final ownerOrderStatusFilterProvider = NotifierProvider.autoDispose<
    OwnerOrderStatusFilterNotifier, OrderStatus?>(
  OwnerOrderStatusFilterNotifier.new,
);

/// Status + accent-insensitive query over name, phone and order number.
List<OrderModel> filterOrders(
  List<OrderModel> orders, {
  OrderStatus? status,
  String query = '',
}) {
  final String q = removeDiacritics(query.trim().toLowerCase());
  return orders.where((OrderModel order) {
    if (status != null && order.status != status) return false;
    if (q.isEmpty) return true;
    final String qNoHash = q.startsWith('#') ? q.substring(1) : q;
    return removeDiacritics(order.customerNameSnapshot.toLowerCase())
            .contains(q) ||
        order.customerPhoneSnapshot.contains(q) ||
        order.orderNumber.toString().contains(qNoHash);
  }).toList();
}

int pendingCount(List<OrderModel> orders) {
  return orders
      .where((OrderModel o) => o.status == OrderStatus.requested)
      .length;
}

class OwnerOrdersState {
  const OwnerOrdersState({this.busyOrderId, this.error});

  final String? busyOrderId;
  final Object? error;
}

class OwnerOrdersController extends Notifier<OwnerOrdersState> {
  @override
  OwnerOrdersState build() => const OwnerOrdersState();

  /// Returns the updated order on success, null on failure.
  Future<OrderModel?> changeStatus(
    OrderModel order,
    OrderStatus next,
  ) async {
    state = OwnerOrdersState(busyOrderId: order.id);
    try {
      final OrderModel updated = await ref
          .read(orderRepositoryProvider)
          .updateStatus(order.id, order.tenantId, next);
      state = const OwnerOrdersState();
      ref.invalidate(ownerOrdersProvider(order.tenantId));
      return updated;
    } catch (e) {
      state = OwnerOrdersState(error: e);
      return null;
    }
  }
}

final ownerOrdersControllerProvider = NotifierProvider.autoDispose<
    OwnerOrdersController, OwnerOrdersState>(
  OwnerOrdersController.new,
);
