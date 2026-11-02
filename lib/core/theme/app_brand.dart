import 'package:all_commerce/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

/// Brand visuals shared by the landing and the app screens.
abstract final class AppBrand {
  /// primary → violet, the signature ALLCommerce gradient.
  static LinearGradient gradient(
    Color primary, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) => LinearGradient(
    colors: <Color>[primary, AppColors.violet],
    begin: begin,
    end: end,
  );

  /// Rich banner gradient from a store's own color (used when it has no
  /// cover image): the color fading into a deeper, slightly shifted hue.
  static LinearGradient tenantGradient(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final Color deep = hsl
        .withHue((hsl.hue + 28) % 360)
        .withLightness((hsl.lightness * 0.72).clamp(0, 1))
        .toColor();
    return LinearGradient(
      colors: <Color>[color, deep],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Same gradient at low opacity, for icon badges on light surfaces.
  static LinearGradient softGradient(Color primary, {double alpha = 0.14}) =>
      LinearGradient(
        colors: <Color>[
          primary.withValues(alpha: alpha),
          AppColors.violet.withValues(alpha: alpha),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

/// Soft two-blob mesh background (cheap radial gradients, no blur) used
/// behind heroes and auth screens.
class BrandBackground extends StatelessWidget {
  const BrandBackground({required this.child, this.intensity = 1, super.key});

  final Widget child;

  /// Multiplies blob opacity (1 = landing strength).
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final double a = (dark ? 0.22 : 0.14) * intensity;
    final double b = (dark ? 0.2 : 0.1) * intensity;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.9, -0.9),
                  radius: 1.1,
                  colors: <Color>[
                    primary.withValues(alpha: a),
                    primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1, -0.3),
                  radius: 0.9,
                  colors: <Color>[
                    AppColors.violet.withValues(alpha: b),
                    AppColors.violet.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Rounded-square icon badge with the soft brand gradient.
class BrandIconBadge extends StatelessWidget {
  const BrandIconBadge({
    required this.icon,
    this.size = 48,
    this.color,
    super.key,
  });

  final IconData icon;
  final double size;

  /// Solid accent instead of the brand gradient (e.g. WhatsApp green).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        color: color?.withValues(alpha: 0.12),
        gradient: color == null ? AppBrand.softGradient(primary) : null,
      ),
      child: Icon(icon, size: size * 0.5, color: color ?? primary),
    );
  }
}
