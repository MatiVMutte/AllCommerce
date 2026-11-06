import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Official AllCommerce bag+sparkles icon mark, optionally followed by the
/// **ALL**Commerce wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.size = 32, this.showWordmark = true, super.key});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final Color text = context.tokens.textPrimary;
    final Widget mark = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: Image.asset(
        'assets/brand_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
    if (!showWordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark,
        SizedBox(width: size * 0.31),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(
                  text: 'ALL',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(
                  text: 'Commerce',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: text.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: size * 0.56,
              color: text,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}
