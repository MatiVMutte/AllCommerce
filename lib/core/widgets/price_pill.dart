import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:flutter/material.dart';

/// White/dark pill with the price, meant to float over photos.
class PricePill extends StatelessWidget {
  const PricePill({
    required this.price,
    this.compareAtPrice,
    super.key,
  });

  final double price;
  final double? compareAtPrice;

  bool get _hasDiscount =>
      compareAtPrice != null && compareAtPrice! > price && price > 0;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 2),
            color: Color(0x1F000000),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_hasDiscount) ...<Widget>[
            Text(
              Formatters.price(compareAtPrice!),
              style: TextStyle(
                color: tokens.textTertiary,
                fontWeight: FontWeight.w500,
                fontSize: 11,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            Formatters.price(price),
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
