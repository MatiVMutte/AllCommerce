import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';

/// Compact pill-styled floating notification that clears the floating nav bar
/// when the caller lives inside a shell ([clearNavBar]) and replaces any
/// queued snackbar so alerts never stack up.
void showAppSnackBar(
  BuildContext context,
  String text, {
  SnackBarAction? action,
  bool clearNavBar = true,
  bool isError = false,
}) {
  final AppTokens tokens = context.tokens;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      width: MediaQuery.sizeOf(context).width >= 600 ? 420 : null,
      elevation: 6,
      duration: Duration(milliseconds: action != null ? 3200 : 1800),
      backgroundColor: isError ? tokens.danger : const Color(0xEE18181B),
      padding: EdgeInsets.fromLTRB(16, 10, action != null ? 8 : 16, 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      margin: MediaQuery.sizeOf(context).width >= 600
          ? null
          : EdgeInsets.fromLTRB(
              24,
              0,
              24,
              clearNavBar ? FloatingNavBar.height + 12 : 16,
            ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      action: action,
    ),
  );
}
