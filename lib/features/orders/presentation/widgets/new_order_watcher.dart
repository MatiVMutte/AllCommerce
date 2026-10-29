import 'dart:async';

import 'package:all_commerce/core/router/app_router.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global ScaffoldMessenger so in-app alerts can be shown from anywhere
/// (incl. this watcher, which lives above the Navigator).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// In-app "new order" alert for owners: polls the orders list while an owner
/// session is active and plays a sound + snackbar when a new pending order
/// arrives. This is the only alerting channel on desktop (no FCM there) and
/// a fallback for web/Android when push is not configured.
class NewOrderWatcher extends ConsumerStatefulWidget {
  const NewOrderWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NewOrderWatcher> createState() => _NewOrderWatcherState();
}

class _NewOrderWatcherState extends ConsumerState<NewOrderWatcher> {
  static const Duration _pollInterval = Duration(seconds: 45);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _poll() {
    final String? tenantId = ref.read(currentProfileProvider).value?.tenantId;
    if (tenantId != null) {
      ref.invalidate(ownerOrdersProvider(tenantId));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _notify() {
    unawaited(SystemSound.play(SystemSoundType.alert));
    AppHaptics.medium();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text('¡Llegó un pedido nuevo!'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Ver pedidos',
          onPressed: () => ref.read(routerProvider).go('/owner/orders'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? tenantId = ref.watch(currentProfileProvider).value?.tenantId;
    if (tenantId != null) {
      ref.listen<AsyncValue<List<OrderModel>>>(ownerOrdersProvider(tenantId), (
        AsyncValue<List<OrderModel>>? prev,
        AsyncValue<List<OrderModel>> next,
      ) {
        final List<OrderModel>? before = prev?.value;
        final List<OrderModel>? after = next.value;
        // Only alert on a real increment, never on the first load.
        if (before != null &&
            after != null &&
            pendingCount(after) > pendingCount(before)) {
          _notify();
        }
      });
    }
    return widget.child;
  }
}
