import 'dart:async';

import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/utils/text_utils.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/orders/data/models/order_item_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/data/models/sales_metrics.dart';
import 'package:all_commerce/features/orders/data/repositories/order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Orders placed by the current user (empty without a session).
final myOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((
  Ref ref,
) async {
  final String? uid = ref.watch(sessionProvider)?.user.id;
  if (uid == null) return <OrderModel>[];
  return ref.watch(orderRepositoryProvider).listMine(uid);
});

final ownerOrdersProvider = FutureProvider.autoDispose
    .family<List<OrderModel>, String>(
      (Ref ref, String tenantId) =>
          ref.watch(orderRepositoryProvider).listByTenant(tenantId),
    );

/// Monthly sales snapshot (totals + top products) for the owner's tenant.
final ownerSalesMetricsProvider = FutureProvider.autoDispose
    .family<SalesMetrics, String>(
      (Ref ref, String tenantId) =>
          ref.watch(orderRepositoryProvider).salesMetrics(tenantId),
    );

final orderItemsProvider = FutureProvider.autoDispose
    .family<List<OrderItemModel>, String>(
      (Ref ref, String orderId) =>
          ref.watch(orderRepositoryProvider).listItems(orderId),
    );

/// null means "all statuses".
class OwnerOrderStatusFilterNotifier extends Notifier<OrderStatus?> {
  @override
  OrderStatus? build() => null;

  void select(OrderStatus? status) => state = status;
}

final ownerOrderStatusFilterProvider =
    NotifierProvider.autoDispose<OwnerOrderStatusFilterNotifier, OrderStatus?>(
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

/// Order selected in the wide master–detail layout (list left, detail
/// right). Null shows the "pick an order" placeholder.
class SelectedOwnerOrderNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedOwnerOrderProvider =
    NotifierProvider<SelectedOwnerOrderNotifier, String?>(
      SelectedOwnerOrderNotifier.new,
    );

class OwnerOrdersState {
  const OwnerOrdersState({this.busyOrderId, this.error});

  final String? busyOrderId;
  final Object? error;
}

class OwnerOrdersController extends Notifier<OwnerOrdersState> {
  @override
  OwnerOrdersState build() => const OwnerOrdersState();

  /// Returns the updated order on success, null on failure.
  Future<OrderModel?> changeStatus(OrderModel order, OrderStatus next) async {
    state = OwnerOrdersState(busyOrderId: order.id);
    try {
      final OrderModel updated = await ref
          .read(orderRepositoryProvider)
          .updateStatus(order.id, order.tenantId, next);
      state = const OwnerOrdersState();
      ref.invalidate(ownerOrdersProvider(order.tenantId));
      // Push to the customer (FCM on Android; no-op if not configured).
      unawaited(ref.read(orderRepositoryProvider).notifyCustomer(updated));
      return updated;
    } catch (e) {
      state = OwnerOrdersState(error: e);
      return null;
    }
  }
}

final ownerOrdersControllerProvider =
    NotifierProvider.autoDispose<OwnerOrdersController, OwnerOrdersState>(
      OwnerOrdersController.new,
    );
