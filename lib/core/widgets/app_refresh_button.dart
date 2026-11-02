import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Circular refresh button shown next to screen titles. Screens keep
/// pull-to-refresh for touch; this gives desktop/web and mouse users a
/// visible way to reload the data.
class AppRefreshButton extends StatefulWidget {
  const AppRefreshButton({
    required this.onRefresh,
    this.tooltip = 'Actualizar',
    this.onDark = false,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final String tooltip;

  /// Translucent white style for use over gradients / photos.
  final bool onDark;

  @override
  State<AppRefreshButton> createState() => _AppRefreshButtonState();
}

class _AppRefreshButtonState extends State<AppRefreshButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color fg = widget.onDark ? Colors.white : tokens.textPrimary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: widget.onDark
            ? Colors.white.withValues(alpha: 0.16)
            : tokens.surface,
        border: widget.onDark ? null : Border.all(color: tokens.border),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: widget.tooltip,
        onPressed: _busy ? null : _run,
        icon: _busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Icon(Icons.refresh_rounded, size: 18, color: fg),
      ),
    );
  }
}
