import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Hairline-bordered card with 20px radius and tactile press scale on tap.
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Widget material = Material(
      color: tokens.surface,
      shape: widget.border is RoundedRectangleBorder
          ? widget.border as RoundedRectangleBorder
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: widget.border is Border
                  ? (widget.border! as Border).top
                  : BorderSide(color: tokens.border),
            ),
      clipBehavior: Clip.antiAlias,
      child: widget.onTap == null
          ? Padding(padding: widget.padding, child: widget.child)
          : InkWell(
              onTap: widget.onTap,
              onHighlightChanged: _setPressed,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
    );
    if (widget.onTap == null) return material;
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: material,
    );
  }
}
