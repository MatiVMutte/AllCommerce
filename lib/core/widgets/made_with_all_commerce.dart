import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/tenant/tenant_strategy.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Acquisition footer under every public catalog: invites the reader
/// (often a neighboring shop owner or a customer who likes the idea) to
/// make their own catalog. In white-label builds it links to the
/// AllCommerce site; in the multi-store app it goes to the /para-locales
/// recruitment landing.
class MadeWithAllCommerce extends StatelessWidget {
  const MadeWithAllCommerce({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool whiteLabel = const TenantResolver().isWhiteLabel;
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          if (whiteLabel) {
            launchUrl(Uri.parse(AppConfig.publicBaseUrl));
          } else {
            context.go('/para-locales');
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.storefront_rounded, size: 15, color: scheme.primary),
              const SizedBox(width: 7),
              Text(
                whiteLabel
                    ? 'Hecho con '
                    : '¿Tenés un local? Creá tu catálogo gratis con ',
                style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
              ),
              Text(
                'AllCommerce',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
