import 'package:all_commerce/core/constants/plans.dart';
import 'package:all_commerce/core/widgets/brand_logo.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/features/billing/data/models/plan_model.dart';
import 'package:all_commerce/features/billing/data/repositories/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Public marketing page for store owners (`/para-locales`).
///
/// Structure follows the patterns of high-converting SaaS pages: product
/// shown in the hero, one primary CTA, proof strip, 3-step "how it works",
/// bento features, comparison, real pricing, FAQ and a closing CTA band.
class LandingView extends StatelessWidget {
  const LandingView({super.key});

  static const double _maxWidth = 1120;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SelectionArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _Hero()),
            SliverToBoxAdapter(
              child: _Section(
                child: Column(
                  children: <Widget>[
                    _ProofStrip(),
                    SizedBox(height: 96),
                    _HowItWorks(),
                    SizedBox(height: 96),
                    _Bento(),
                    SizedBox(height: 96),
                    _Comparison(),
                    SizedBox(height: 96),
                    _Pricing(),
                    SizedBox(height: 96),
                    _Faq(),
                    SizedBox(height: 96),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _FinalCta()),
            SliverToBoxAdapter(child: _Footer()),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

bool _isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

/// Buttons in the global theme have an infinite min width; landing buttons
/// must hug their label so they can sit side by side.
ButtonStyle _compact({double height = 52}) => ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(Size(0, height)),
  padding: const WidgetStatePropertyAll<EdgeInsets>(
    EdgeInsets.symmetric(horizontal: 22),
  ),
);

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LandingView._maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Column(
      children: <Widget>[
        _Eyebrow(eyebrow),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _isWide(context) ? 40 : 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: tokens.textPrimary,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.5,
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final bool wide = _isWide(context);
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: <Widget>[
        // Soft mesh background: two cheap radial gradients (no blur filter).
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.9, -0.8),
                radius: 1.1,
                colors: <Color>[
                  primary.withValues(alpha: dark ? 0.22 : 0.14),
                  primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(1, -0.2),
                radius: 0.9,
                colors: <Color>[
                  const Color(0xFF7C3AED).withValues(alpha: dark ? 0.2 : 0.1),
                  const Color(0x007C3AED),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: _Section(
            child: Column(
              children: <Widget>[
                const _NavBar(),
                SizedBox(height: wide ? 56 : 32),
                if (wide)
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(flex: 11, child: _HeroCopy(center: false)),
                      SizedBox(width: 48),
                      Expanded(flex: 9, child: _PhoneMockup()),
                    ],
                  )
                else ...const <Widget>[
                  _HeroCopy(center: true),
                  SizedBox(height: 48),
                  _PhoneMockup(),
                ],
                SizedBox(height: wide ? 80 : 56),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    final bool wide = _isWide(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.go('/'),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: BrandLogo(),
                ),
              ),
            ),
          ),
          TextButton(
            style: _compact(height: 40).copyWith(
              padding: const WidgetStatePropertyAll<EdgeInsets>(
                EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            onPressed: () => context.push('/login'),
            child: const Text('Ingresar'),
          ),
          if (wide) ...<Widget>[
            const SizedBox(width: 8),
            FilledButton(
              style: _compact(height: 42),
              onPressed: () => context.push('/register'),
              child: const Text('Crear mi local'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.center});

  final bool center;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool wide = _isWide(context);
    final TextAlign align = center ? TextAlign.center : TextAlign.start;
    final CrossAxisAlignment cross = center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final TextStyle headline = TextStyle(
      fontSize: wide ? 64 : 42,
      height: 1.02,
      fontWeight: FontWeight.w900,
      letterSpacing: wide ? -2.5 : -1.5,
      color: tokens.textPrimary,
    );
    return Column(
      crossAxisAlignment: cross,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'NUEVO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Cargá productos con una foto, la IA hace el resto',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              const TextSpan(text: 'Tu local,\n'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (Rect bounds) => LinearGradient(
                    colors: <Color>[primary, const Color(0xFF7C3AED)],
                  ).createShader(bounds),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('vendiendo online', style: headline),
                  ),
                ),
              ),
              const TextSpan(text: '\nen 5 minutos.'),
            ],
          ),
          textAlign: align,
          style: headline,
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Creá tu catálogo gratis, compartí tu link o QR y recibí '
            'pedidos armados por WhatsApp. Sin comisiones, sin '
            'programar, desde el celular.',
            textAlign: align,
            style: TextStyle(
              fontSize: wide ? 19 : 17,
              height: 1.55,
              color: tokens.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.icon(
              style: _compact(height: 56),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              iconAlignment: IconAlignment.end,
              label: const Text(
                'Crear mi local gratis',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: () => context.push('/register'),
            ),
            OutlinedButton(
              style: _compact(height: 56),
              onPressed: () => context.go('/'),
              child: const Text('Ver locales', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          spacing: 18,
          runSpacing: 8,
          children: const <Widget>[
            _Check('Gratis para siempre'),
            _Check('Sin tarjeta'),
            _Check('0% comisión'),
          ],
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.check_circle_rounded, size: 18, color: tokens.success),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Phone mockup (pure widgets: always matches the real product's look)
// ---------------------------------------------------------------------------

class _PhoneMockup extends StatefulWidget {
  const _PhoneMockup();

  @override
  State<_PhoneMockup> createState() => _PhoneMockupState();
}

class _PhoneMockupState extends State<_PhoneMockup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    _float.repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) _float.stop();
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 380,
          height: 560,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              const _Phone(),
              // Floating "new order" notification.
              AnimatedBuilder(
                animation: _float,
                builder: (BuildContext context, Widget? child) => Positioned(
                  top: 70 + _float.value * 10,
                  right: -4,
                  child: child!,
                ),
                child: const _FloatingCard(
                  icon: Icons.chat_rounded,
                  iconColor: Color(0xFF25D366),
                  title: 'Nuevo pedido #128',
                  subtitle: r'3 productos · $24.500',
                ),
              ),
              // Floating AI chip.
              AnimatedBuilder(
                animation: _float,
                builder: (BuildContext context, Widget? child) => Positioned(
                  bottom: 80 - _float.value * 10,
                  left: -6,
                  child: child!,
                ),
                child: const _FloatingCard(
                  icon: Icons.auto_awesome,
                  iconColor: Color(0xFF7C3AED),
                  title: 'La IA completó el producto',
                  subtitle: 'Yerba Playadito 1 kg',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Phone extends StatelessWidget {
  const _Phone();

  static const List<(String, String, Color)> _products =
      <(String, String, Color)>[
        ('Alfajor triple', r'$1.200', Color(0xFFFDE68A)),
        ('Café molido 500 g', r'$6.900', Color(0xFFFECACA)),
        ('Jabón líquido', r'$3.450', Color(0xFFBFDBFE)),
        ('Pan de campo', r'$2.800', Color(0xFFBBF7D0)),
      ];

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 270,
      height: 540,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(44),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: primary.withValues(alpha: 0.25),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 34, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[primary, const Color(0xFF3B2DB5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.storefront_rounded,
                        size: 18,
                        color: Color(0xFF0B0F19),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Almacén Don Pepe',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: <Widget>[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4ADE80),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Abierto · Avellaneda',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Buscar productos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.8,
                  children: <Widget>[
                    for (final (String name, String price, Color color)
                        in _products)
                      _MiniProduct(name: name, price: price, color: color),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.chat_rounded, color: Colors.white, size: 17),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        r'Pedir por WhatsApp · $10.100',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniProduct extends StatelessWidget {
  const _MiniProduct({
    required this.name,
    required this.price,
    required this.color,
  });

  final String name;
  final String price;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      price,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0B0F19),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0B0F19),
          ),
        ),
      ],
    );
  }
}

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proof strip
// ---------------------------------------------------------------------------

class _ProofStrip extends StatelessWidget {
  const _ProofStrip();

  static const List<(String, String)> _items = <(String, String)>[
    ('5 min', 'para tener tu catálogo online'),
    ('0%', 'de comisión por cada venta'),
    (r'$0', 'para empezar, para siempre'),
    ('24/7', 'tu local abierto en internet'),
  ];

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool wide = _isWide(context);
    final List<Widget> cells = <Widget>[
      for (final (String value, String label) in _items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: <Widget>[
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (Rect b) => LinearGradient(
                  colors: <Color>[
                    Theme.of(context).colorScheme.primary,
                    const Color(0xFF7C3AED),
                  ],
                ).createShader(b),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: tokens.textSecondary),
              ),
            ],
          ),
        ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: wide
          ? Row(
              children: <Widget>[
                for (final Widget c in cells) Expanded(child: c),
              ],
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < cells.length; i += 2)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(child: cells[i]),
                        Expanded(child: cells[i + 1]),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// How it works
// ---------------------------------------------------------------------------

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const List<(IconData, String, String)> _steps =
      <(IconData, String, String)>[
        (
          Icons.storefront_rounded,
          'Creá tu local',
          'Nombre, WhatsApp y dirección. En menos de 5 minutos tu '
              'catálogo ya tiene link propio.',
        ),
        (
          Icons.photo_camera_rounded,
          'Sacale una foto a tus productos',
          'La IA completa título, descripción, categoría y precio '
              'sugerido. Vos solo revisás y publicás.',
        ),
        (
          Icons.qr_code_2_rounded,
          'Compartí y recibí pedidos',
          'Pasá tu link por WhatsApp o Instagram, o pegá el QR en el '
              'mostrador. Los pedidos te llegan armados.',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final bool wide = _isWide(context);
    final List<Widget> cards = <Widget>[
      for (final (int i, (IconData icon, String title, String text))
          in _steps.indexed)
        _StepCard(number: i + 1, icon: icon, title: title, text: text),
    ];
    return Column(
      children: <Widget>[
        const _SectionTitle(
          eyebrow: 'Cómo funciona',
          title: 'De cero a vender, en 3 pasos',
          subtitle:
              'Sin diseñadores, sin programar y sin pagar nada para '
              'empezar.',
        ),
        const SizedBox(height: 48),
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (int i, Widget c) in cards.indexed) ...<Widget>[
                  if (i > 0) const SizedBox(width: 20),
                  Expanded(child: c),
                ],
              ],
            ),
          )
        else
          Column(
            children: <Widget>[
              for (final (int i, Widget c) in cards.indexed) ...<Widget>[
                if (i > 0) const SizedBox(height: 16),
                c,
              ],
            ],
          ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
  });

  final int number;
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primary, size: 24),
              ),
              const Spacer(),
              Text(
                '0$number',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: tokens.border,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bento features
// ---------------------------------------------------------------------------

class _Bento extends StatelessWidget {
  const _Bento();

  @override
  Widget build(BuildContext context) {
    final bool wide = _isWide(context);
    final Color primary = Theme.of(context).colorScheme.primary;
    final Widget ai = _BentoCard(
      gradient: <Color>[primary, const Color(0xFF7C3AED)],
      icon: Icons.auto_awesome,
      title: 'Carga con inteligencia artificial',
      text:
          'Una foto y listo: título, descripción, categoría, etiquetas y '
          'precio sugerido. Cargá decenas de productos de una con la '
          'carga masiva.',
      tall: true,
    );
    const Widget whatsapp = _BentoCard(
      accent: Color(0xFF25D366),
      icon: Icons.chat_rounded,
      title: 'Pedidos armados por WhatsApp',
      text:
          'Carrito real, cupones y medios de pago. Te llega el pedido '
          'completo, listo para cobrar.',
    );
    const Widget push = _BentoCard(
      accent: Color(0xFFF59E0B),
      icon: Icons.notifications_active_rounded,
      title: 'Avisos al instante',
      text:
          'Push cuando entra un pedido. Tu cliente recibe un aviso con '
          'cada cambio de estado.',
    );
    const Widget stock = _BentoCard(
      accent: Color(0xFF0EA5E9),
      icon: Icons.inventory_2_rounded,
      title: 'Stock, talles y venta por kilo',
      text:
          'Variantes, precios mayoristas, ofertas y stock que se descuenta '
          'solo con cada pedido.',
    );
    const Widget stats = _BentoCard(
      accent: Color(0xFFEC4899),
      icon: Icons.insights_rounded,
      title: 'Tus números, claros',
      text:
          'Visitas al catálogo, ventas del mes, productos más vendidos y '
          'exportación a Excel.',
    );
    const Widget brand = _BentoCard(
      accent: Color(0xFF16A34A),
      icon: Icons.palette_rounded,
      title: 'Con tu marca',
      text:
          'Tu logo y tu color en todo el catálogo. Link propio, QR para '
          'imprimir y aparecés en el mapa de locales.',
    );
    return Column(
      children: <Widget>[
        const _SectionTitle(
          eyebrow: 'Todo incluido',
          title: 'Todo lo que tu local necesita',
          subtitle:
              'Por eso se llama ALL: todas las herramientas para vender, '
              'en una sola app.',
        ),
        const SizedBox(height: 48),
        if (wide)
          Column(
            children: <Widget>[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(flex: 5, child: ai),
                    const SizedBox(width: 20),
                    const Expanded(
                      flex: 7,
                      child: Column(
                        children: <Widget>[
                          whatsapp,
                          SizedBox(height: 20),
                          push,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: stock),
                    SizedBox(width: 20),
                    Expanded(child: stats),
                    SizedBox(width: 20),
                    Expanded(child: brand),
                  ],
                ),
              ),
            ],
          )
        else
          Column(
            children: <Widget>[
              ai,
              for (final Widget w in const <Widget>[
                whatsapp,
                push,
                stock,
                stats,
                brand,
              ]) ...<Widget>[const SizedBox(height: 16), w],
            ],
          ),
      ],
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.icon,
    required this.title,
    required this.text,
    this.accent,
    this.gradient,
    this.tall = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color? accent;
  final List<Color>? gradient;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool filled = gradient != null;
    final Color fg = filled ? Colors.white : tokens.textPrimary;
    final Color fgSoft = filled
        ? Colors.white.withValues(alpha: 0.85)
        : tokens.textSecondary;
    final Color iconColor = filled ? Colors.white : accent!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: filled ? null : tokens.surface,
        gradient: filled
            ? LinearGradient(
                colors: gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: filled ? null : Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: tall
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: filled
                  ? Colors.white.withValues(alpha: 0.18)
                  : iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(height: tall ? 40 : 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: tall ? 26 : 18,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: tall ? -0.8 : -0.3,
                  color: fg,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                style: TextStyle(
                  fontSize: tall ? 16 : 14.5,
                  height: 1.5,
                  color: fgSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comparison: WhatsApp alone vs ALLCommerce
// ---------------------------------------------------------------------------

class _Comparison extends StatelessWidget {
  const _Comparison();

  static const List<String> _rows = <String>[
    'Carrito con total calculado',
    'Stock que se descuenta solo',
    'Pedidos ordenados por estado',
    'Cupones y precios mayoristas',
    'Estadísticas de visitas y ventas',
    'Carga de productos con IA',
    'Catálogo con tu logo y color',
  ];

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    final TextStyle head = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: tokens.textSecondary,
    );
    return Column(
      children: <Widget>[
        const _SectionTitle(
          eyebrow: 'La diferencia',
          title: 'Vender por WhatsApp,\npero bien hecho',
          subtitle:
              'Seguís atendiendo por WhatsApp como siempre. Lo que cambia '
              'es todo lo que pasa antes del mensaje.',
        ),
        const SizedBox(height: 48),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: tokens.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Row(
                    children: <Widget>[
                      const Expanded(child: SizedBox()),
                      SizedBox(
                        width: 96,
                        child: Text(
                          'Solo\nWhatsApp',
                          textAlign: TextAlign.center,
                          style: head,
                        ),
                      ),
                      SizedBox(
                        width: 112,
                        child: Text(
                          'ALLCommerce',
                          textAlign: TextAlign.center,
                          style: head.copyWith(color: primary),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final (int i, String row) in _rows.indexed)
                  Container(
                    color: i.isEven ? tokens.surfaceMuted : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            row,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: tokens.textTertiary,
                          ),
                        ),
                        SizedBox(
                          width: 112,
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 22,
                            color: tokens.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pricing (live from the `plans` table)
// ---------------------------------------------------------------------------

class _Pricing extends ConsumerWidget {
  const _Pricing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PlanModel> plans =
        (ref.watch(plansProvider).value ?? const <PlanModel>[])
            .where((PlanModel p) => p.id != PlanType.trial)
            .toList()
          ..sort((PlanModel a, PlanModel b) {
            if (a.id == PlanType.free) return -1;
            if (b.id == PlanType.free) return 1;
            return a.sortOrder.compareTo(b.sortOrder);
          });
    return Column(
      children: <Widget>[
        const _SectionTitle(
          eyebrow: 'Precios',
          title: 'Empezá gratis.\nCrecé cuando quieras.',
          subtitle:
              'El plan Gratis es para siempre. Sin comisiones por venta en '
              'ningún plan: lo que vendés es tuyo.',
        ),
        const SizedBox(height: 48),
        if (plans.isEmpty)
          const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final PlanModel p in plans)
                _PlanCard(plan: p, highlighted: p.id == PlanType.crecimiento),
            ],
          ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.highlighted});

  final PlanModel plan;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool free = plan.priceArs == 0;
    final Color fg = highlighted ? Colors.white : tokens.textPrimary;
    final Color fgSoft = highlighted
        ? Colors.white.withValues(alpha: 0.8)
        : tokens.textSecondary;
    return Container(
      width: 252,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF0B0F19) : tokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlighted ? primary : tokens.border,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              if (highlighted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Recomendado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  free ? r'$0' : Formatters.price(plan.priceArs),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: fg,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7, left: 4),
                  child: Text(
                    free ? 'para siempre' : '/mes',
                    style: TextStyle(fontSize: 13, color: fgSoft),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final String h in plan.highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: highlighted ? primary : tokens.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: fgSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: highlighted
                ? FilledButton(
                    style: _compact(height: 46),
                    onPressed: () => context.push('/register'),
                    child: const Text('Empezar'),
                  )
                : OutlinedButton(
                    style: _compact(height: 46),
                    onPressed: () => context.push('/register'),
                    child: Text(free ? 'Crear gratis' : 'Empezar'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAQ
// ---------------------------------------------------------------------------

class _Faq extends StatelessWidget {
  const _Faq();

  static const List<(String, String)> _items = <(String, String)>[
    (
      '¿Es gratis de verdad?',
      'Sí. El plan Gratis no vence: hasta 5 productos, pedidos por '
          'WhatsApp y aparecer en el directorio y mapa. Si necesitás más '
          'productos, pasás a un plan pago cuando quieras.',
    ),
    (
      '¿Cobran comisión por venta?',
      'No. El cliente te paga a vos directo — efectivo, transferencia o '
          'Mercado Pago. Nunca tocamos tu plata.',
    ),
    (
      '¿Mis clientes tienen que descargar una app?',
      'No. Tu catálogo se abre desde cualquier navegador con tu link o '
          'tu QR. Si quieren, pueden instalarla para pedir más rápido.',
    ),
    (
      '¿Necesito saber de tecnología?',
      'Para nada. Si sabés usar WhatsApp, sabés usar ALLCommerce. La IA '
          'te completa los productos a partir de una foto.',
    ),
    (
      '¿Puedo cancelar o cambiar de plan?',
      'Cuando quieras, sin permanencia. Si dejás de pagar, tu local vuelve '
          'al plan Gratis.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Column(
      children: <Widget>[
        const _SectionTitle(
          eyebrow: 'Preguntas',
          title: 'Preguntas frecuentes',
        ),
        const SizedBox(height: 40),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: <Widget>[
              for (final (String q, String a) in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: tokens.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: tokens.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 4,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          22,
                          0,
                          22,
                          20,
                        ),
                        expandedAlignment: Alignment.centerLeft,
                        title: Text(
                          q,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                        children: <Widget>[
                          Text(
                            a,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.55,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Final CTA + footer
// ---------------------------------------------------------------------------

class _FinalCta extends StatelessWidget {
  const _FinalCta();

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool wide = _isWide(context);
    return _Section(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 64 : 28,
          vertical: wide ? 72 : 48,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: RadialGradient(
            center: const Alignment(0.8, -1),
            radius: 1.6,
            colors: <Color>[primary, const Color(0xFF0B0F19)],
          ),
        ),
        child: Column(
          children: <Widget>[
            Text(
              'Tu local merece estar online.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: wide ? 46 : 32,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Creá tu catálogo ahora y recibí tu primer pedido hoy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              style: _compact(height: 58).copyWith(
                backgroundColor: const WidgetStatePropertyAll<Color>(
                  Colors.white,
                ),
                foregroundColor: const WidgetStatePropertyAll<Color>(
                  Color(0xFF0B0F19),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              iconAlignment: IconAlignment.end,
              label: const Text(
                'Crear mi local gratis',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              onPressed: () => context.push('/register'),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 8,
              children: <Widget>[
                for (final String t in const <String>[
                  'Gratis para siempre',
                  'Sin tarjeta',
                  '0% comisión',
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final TextStyle link = TextStyle(fontSize: 14, color: tokens.textSecondary);
    return _Section(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 24,
          runSpacing: 16,
          children: <Widget>[
            const BrandLogo(),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: <Widget>[
                InkWell(
                  onTap: () => context.go('/'),
                  child: Text('Locales', style: link),
                ),
                InkWell(
                  onTap: () => context.push('/terms'),
                  child: Text('Términos', style: link),
                ),
                InkWell(
                  onTap: () => context.push('/privacy'),
                  child: Text('Privacidad', style: link),
                ),
              ],
            ),
            Text(
              '© ${DateTime.now().year} ALLCommerce · Hecho en Argentina',
              style: TextStyle(fontSize: 13, color: tokens.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
