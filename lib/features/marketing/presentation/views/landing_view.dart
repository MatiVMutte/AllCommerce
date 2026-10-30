import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Public marketing page for store owners (`/para-locales`).
/// Sells the product to owners and sends them to register.
class LandingView extends StatelessWidget {
  const LandingView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/'),
        title: const Text(AppStrings.appName),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.push('/login'),
            child: const Text('Ingresar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 24),
                  _Hero(wide: wide),
                  const SizedBox(height: 40),
                  Text(
                    'Todo lo que tu local necesita',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _FeatureGrid(wide: wide),
                  const SizedBox(height: 40),
                  const _Plans(),
                  const SizedBox(height: 40),
                  _FinalCta(primary: primary, tokens: tokens),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Para dueños de local',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tu catálogo online con IA.\nGratis para siempre.',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: wide ? null : 32,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Sacás una foto, la IA carga el producto, compartís tu link '
            'y tus clientes te piden por WhatsApp. Así de simple.',
            style: TextStyle(fontSize: 16, color: tokens.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.icon(
              icon: const Icon(Icons.storefront_outlined, size: 20),
              label: const Text('Crear mi local'),
              onPressed: () => context.push('/register'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.explore_outlined, size: 20),
              label: const Text('Ver locales'),
              onPressed: () => context.go('/'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Sin tarjeta · 5 minutos · Funciona en cualquier celular',
          style: TextStyle(fontSize: 13, color: tokens.textTertiary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.wide});

  final bool wide;

  static const List<_Feature> _features = <_Feature>[
    _Feature(
      Icons.auto_awesome,
      'Carga con IA',
      'Una foto del producto y la IA completa título, descripción, '
          'categoría y precio sugerido.',
    ),
    _Feature(
      Icons.chat_bubble_outline_rounded,
      'Pedidos por WhatsApp',
      'El cliente arma el carrito en tu catálogo y te llega el pedido '
          'armado y listo para cobrar.',
    ),
    _Feature(
      Icons.notifications_active_outlined,
      'Notificaciones',
      'Te avisamos al instante cuando entra un pedido nuevo, y tu '
          'cliente recibe un aviso con cada cambio de estado.',
    ),
    _Feature(
      Icons.qr_code_2_outlined,
      'Tu link y tu QR',
      'Un link propio (allcommerce.app/s/tu-local) y un QR listo para '
          'imprimir y pegar en el local.',
    ),
    _Feature(
      Icons.inventory_2_outlined,
      'Stock y variantes real',
      'Talles, colores, venta por kilo o litro, stock que se descuenta '
          'solo con cada pedido.',
    ),
    _Feature(
      Icons.bar_chart_outlined,
      'Estadísticas y export',
      'Visitas a tu catálogo, ventas del mes y exportación a Excel '
          'en un toque.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final double width = wide ? 430 : double.infinity;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: _features.map((_Feature f) {
        return Container(
          width: width,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.1),
                ),
                child: Icon(
                  f.icon,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      f.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f.text,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;
}

class _Plans extends StatelessWidget {
  const _Plans();

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    return Column(
      children: <Widget>[
        Text(
          'Empezá gratis, crecé cuando quieras',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: <Widget>[
            _PlanCard(
              name: 'Gratis',
              price: r'$0',
              items: const <String>[
                'Hasta 5 productos',
                'Pedidos por WhatsApp',
                'Tu link y QR propio',
                'Para siempre, sin trucos',
              ],
              highlighted: false,
              tokens: tokens,
            ),
            _PlanCard(
              name: 'Pro',
              price: 'Hasta 1.000',
              priceSuffix: 'productos',
              items: const <String>[
                'Catálogo completo',
                'Carga masiva con IA',
                'Estadísticas avanzadas',
                'Soporte prioritario',
              ],
              highlighted: true,
              tokens: tokens,
              accent: primary,
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.items,
    required this.highlighted,
    required this.tokens,
    this.priceSuffix,
    this.accent,
  });

  final String name;
  final String price;
  final String? priceSuffix;
  final List<String> items;
  final bool highlighted;
  final AppTokens tokens;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color border = highlighted
        ? (accent ?? tokens.border)
        : tokens.border;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: highlighted ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                price,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: highlighted ? accent : tokens.textPrimary,
                ),
              ),
              if (priceSuffix != null)
                Text(
                  ' $priceSuffix',
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (final String item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 17,
                    color: tokens.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.primary, required this.tokens});

  final Color primary;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            primary.withValues(alpha: 0.12),
            primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '¿Listo para vender online?',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Creá tu local ahora y compartí tu catálogo hoy mismo.',
            style: TextStyle(fontSize: 14, color: tokens.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.rocket_launch_outlined, size: 20),
            label: const Text('Crear mi local gratis'),
            onPressed: () => context.push('/register'),
          ),
        ],
      ),
    );
  }
}
