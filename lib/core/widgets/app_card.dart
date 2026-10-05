import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Hairline-bordered card with 20px radius and optional tap.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.border,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Overrides the default hairline border (e.g. primary 2px).
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Material(
      color: tokens.surface,
      shape: border is RoundedRectangleBorder
          ? border as RoundedRectangleBorder
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: border is Border
                  ? (border! as Border).top
                  : BorderSide(color: tokens.border),
            ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}
