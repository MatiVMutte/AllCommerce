import 'package:all_commerce/core/theme/app_brand.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_motion.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

/// Empty state: icon in a muted circle, title, subtitle, optional CTA.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool animate = AppMotion.enabled(context);
    final Color primary = Theme.of(context).colorScheme.primary;
    // Brand-gradient badge with a soft halo ring, like the landing icons.
    final Widget avatar = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppBrand.softGradient(primary, alpha: 0.07),
      ),
      child: BrandIconBadge(icon: icon, size: 76),
    );
    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          animate
              ? ZoomIn(
                  duration: const Duration(milliseconds: 320),
                  child: avatar,
                )
              : avatar,
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: tokens.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: tokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null) ...<Widget>[
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: animate
            ? FadeInUp(
                duration: const Duration(milliseconds: 280),
                from: 14,
                child: content,
              )
            : content,
      ),
    );
  }
}

/// Error state with retry button.
class AppErrorState extends StatelessWidget {
  const AppErrorState({this.onRetry, super.key});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Ocurrió un error',
      subtitle: 'Revisá tu conexión e intentá de nuevo',
      actionLabel: 'Reintentar',
      onAction: onRetry,
    );
  }
}
