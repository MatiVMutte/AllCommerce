import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Payload passed via `state.extra` from the cart flow.
class OrderConfirmation {
  const OrderConfirmation({required this.order, required this.whatsappUri});

  final OrderModel order;
  final String whatsappUri;
}

class OrderSuccessView extends StatelessWidget {
  const OrderSuccessView({
    required this.slug,
    this.confirmation,
    super.key,
  });

  final String slug;

  /// Null when the page is reloaded / deep-linked without extras.
  final OrderConfirmation? confirmation;

  @override
  Widget build(BuildContext context) {
    final OrderConfirmation? data = confirmation;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallback: '/s/$slug'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  data == null
                      ? '¡Pedido enviado!'
                      : '¡Pedido #${data.order.orderNumber} enviado!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (data != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('Total ${Formatters.price(data.order.total)}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Si WhatsApp no se abrió, tocá el botón:',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Abrir WhatsApp'),
                    onPressed: () => launchUrl(
                      Uri.parse(data.whatsappUri),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/s/$slug'),
                  child: const Text('Volver al catálogo'),
                ),
                TextButton(
                  onPressed: () => context.go('/my-orders'),
                  child: const Text('Ver mis pedidos'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
