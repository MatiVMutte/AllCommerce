import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_motion.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/made_with_all_commerce.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Payload passed via `state.extra` from the cart flow.
class OrderConfirmation {
  const OrderConfirmation({required this.order, required this.whatsappUri});

  final OrderModel order;
  final String whatsappUri;
}

class OrderSuccessView extends StatelessWidget {
  const OrderSuccessView({required this.slug, this.confirmation, super.key});

  final String slug;

  /// Null when the page is reloaded / deep-linked without extras.
  final OrderConfirmation? confirmation;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final OrderConfirmation? data = confirmation;
    final bool animate = AppMotion.enabled(context);
    Widget fade(Widget child, int delayMs) => animate
        ? FadeInUp(
            duration: const Duration(milliseconds: 320),
            delay: Duration(milliseconds: delayMs),
            from: 14,
            child: child,
          )
        : child;
    return Scaffold(
      appBar: AppBar(leading: AppBackButton(fallback: '/s/$slug')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: tokens.success.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 56,
                        color: tokens.success,
                      ),
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.4, 0.4),
                      end: const Offset(1, 1),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 200.ms),
                const SizedBox(height: 20),
                fade(
                  Text(
                    data == null
                        ? '¡Pedido enviado!'
                        : '¡Pedido #${data.order.orderNumber} enviado!',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  150,
                ),
                if (data != null) ...<Widget>[
                  const SizedBox(height: 8),
                  fade(
                    Text(
                      'Total ${Formatters.price(data.order.total)}',
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                    260,
                  ),
                  const SizedBox(height: 8),
                  fade(
                    Text(
                      'El local recibió tu pedido. Si WhatsApp no se '
                      'abrió, tocá el botón:',
                      style: TextStyle(color: tokens.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    340,
                  ),
                  const SizedBox(height: 16),
                  fade(
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.chat_bubble_rounded),
                        label: const Text('Abrir WhatsApp'),
                        onPressed: () => launchUrl(
                          Uri.parse(data.whatsappUri),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ),
                    420,
                  ),
                ],
                const SizedBox(height: 12),
                fade(
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => context.go('/my-orders'),
                      child: const Text('Ver mis pedidos'),
                    ),
                  ),
                  480,
                ),
                const SizedBox(height: 8),
                fade(
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/s/$slug'),
                      child: const Text('Seguir comprando'),
                    ),
                  ),
                  540,
                ),
                const SizedBox(height: 16),
                const MadeWithAllCommerce(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
