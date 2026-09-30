import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Bottom-sheet confirmation dialog in the app's visual style.
/// Returns true when the user confirms, false/null otherwise.
Future<bool?> showAppConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) {
      final AppTokens tokens = context.tokens;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: tokens.textSecondary),
            ),
            const SizedBox(height: 20),
            if (destructive)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              )
            else
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    },
  );
}
