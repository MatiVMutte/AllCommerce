import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';

/// Floating snackbar that clears the floating nav bar when the caller
/// lives inside a shell ([clearNavBar]).
void showAppSnackBar(
  BuildContext context,
  String text, {
  SnackBarAction? action,
  bool clearNavBar = true,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        clearNavBar ? FloatingNavBar.height + 16 : 16,
      ),
      content: Text(text),
      action: action,
    ),
  );
}
