import 'package:flutter/material.dart';

/// Wraps a subtree so `colorScheme.primary` becomes the store's brand
/// color — buttons, steppers, links and accents inside a tenant's
/// catalog/cart/detail then look like the local's own app.
class TenantTheme extends StatelessWidget {
  const TenantTheme({required this.brandColor, required this.child, super.key});

  final Color brandColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final Color onBrand = brandColor.computeLuminance() > 0.45
        ? const Color(0xFF1A1A1A)
        : Colors.white;
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: brandColor,
          onPrimary: onBrand,
        ),
      ),
      child: child,
    );
  }
}
