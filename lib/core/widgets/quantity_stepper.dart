import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';

/// Compact − n + stepper with haptics.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.quantity,
    required this.onChanged,
    this.maxQuantity,
    this.dense = false,
    super.key,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int? maxQuantity;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final double size = dense ? 28 : 36;
    final bool canIncrement = maxQuantity == null || quantity < maxQuantity!;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepButton(
            icon: Icons.remove,
            size: size,
            onPressed: () {
              AppHaptics.light();
              onChanged(quantity - 1);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$quantity',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: dense ? 13 : 15,
                color: tokens.textPrimary,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            size: size,
            onPressed: canIncrement
                ? () {
                    AppHaptics.light();
                    onChanged(quantity + 1);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.size,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: size * 0.55,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}
