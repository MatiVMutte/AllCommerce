import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Circular muted back button: pops when possible, else goes to
/// [fallback] (deep links / web reloads).
class AppBackButton extends StatelessWidget {
  const AppBackButton({required this.fallback, super.key});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Center(
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: tokens.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: BackButton(
          style: IconButton.styleFrom(
            foregroundColor: tokens.textPrimary,
            padding: EdgeInsets.zero,
          ),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(fallback),
        ),
      ),
    );
  }
}
