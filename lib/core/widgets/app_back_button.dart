import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back button that pops the navigation stack when possible, otherwise
/// goes to [fallback] (covers deep links / web reloads).
class AppBackButton extends StatelessWidget {
  const AppBackButton({required this.fallback, super.key});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return BackButton(
      onPressed: () =>
          context.canPop() ? context.pop() : context.go(fallback),
    );
  }
}
