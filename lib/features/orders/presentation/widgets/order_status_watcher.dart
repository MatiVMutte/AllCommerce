import 'dart:async';

import 'package:all_commerce/core/constants/order_status.dart';
import 'package:all_commerce/core/router/app_router.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:all_commerce/features/orders/presentation/widgets/new_order_watcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-app "order status changed" alert for customers: polls the customer's
/// orders while a session is active and plays a sound + snackbar when the
/// store moves an order to a new status. Companion of [NewOrderWatcher] —
/// this is the only alerting channel on desktop (no FCM there).
class OrderStatusWatcher extends ConsumerStatefulWidget {
  const OrderStatusWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OrderStatusWatcher> createState() => _OrderStatusWatcherState();
}

class _OrderStatusWatcherState extends ConsumerState<OrderStatusWatcher> {
  static const Duration _pollInterval = Duration(seconds: 45);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _poll() {
    if (ref.read(sessionProvider) != null) {
      ref.invalidate(myOrdersProvider);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _notify(OrderModel order) {
    unawaited(SystemSound.play(SystemSoundType.alert));
    AppHaptics.medium();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Tu pedido #${order.orderNumber}: ${order.status.label}'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Ver mis pedidos',
          onPressed: () => ref.read(routerProvider).go('/my-orders'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider) != null) {
      ref.listen<AsyncValue<List<OrderModel>>>(myOrdersProvider, (
        AsyncValue<List<OrderModel>>? prev,
        AsyncValue<List<OrderModel>> next,
      ) {
        final List<OrderModel>? before = prev?.value;
        final List<OrderModel>? after = next.value;
        // Only alert on real transitions, never on the first load.
        if (before == null || after == null) return;
        final Map<String, OrderStatus> previous = <String, OrderStatus>{
          for (final OrderModel o in before) o.id: o.status,
        };
        for (final OrderModel order in after) {
          final OrderStatus? old = previous[order.id];
          if (old != null && old != order.status) {
            _notify(order);
          }
        }
      });
    }
    return widget.child;
  }
}
