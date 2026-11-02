import 'package:all_commerce/core/theme/app_brand.dart';
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(leading: AppBackButton(fallback: '/s/$slug')),
      body: BrandBackground(
        intensity: 0.7,
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 88, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tokens.success.withValues(alpha: 0.1),
                          ),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFF22C55E),
                                  Color(0xFF15803D),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: tokens.success.withValues(alpha: 0.35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 56,
                              color: Colors.white,
                            ),
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
                    const SizedBox(height: 28),
                    fade(
                      Text(
                        '¡Pedido enviado!',
                        style: Theme.of(context).textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                      150,
                    ),
                    if (data != null) ...<Widget>[
                      const SizedBox(height: 20),
                      fade(
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: tokens.border),
                          ),
                          child: Row(
                            children: <Widget>[
                              const BrandIconBadge(
                                icon: Icons.receipt_long_rounded,
                                size: 48,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Pedido #${data.order.orderNumber}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Te avisamos cuando cambie de estado',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                Formatters.price(data.order.total),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        260,
                      ),
                      const SizedBox(height: 16),
                      fade(
                        Text(
                          'El local ya recibió tu pedido. Si WhatsApp no se '
                          'abrió, tocá el botón:',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: tokens.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        340,
                      ),
                      const SizedBox(height: 16),
                      fade(
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                            ),
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
        ),
      ),
    );
  }
}
