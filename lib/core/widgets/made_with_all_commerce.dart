import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/tenant/tenant_strategy.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Hecho con AllCommerce" footer. In white-label builds it links to the
/// AllCommerce site; in the multi-store app it goes to the store directory.
class MadeWithAllCommerce extends StatelessWidget {
  const MadeWithAllCommerce({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          if (const TenantResolver().isWhiteLabel) {
            launchUrl(Uri.parse(AppConfig.publicBaseUrl));
          } else {
            context.go('/');
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.storefront_rounded,
                size: 14,
                color: tokens.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                'Hecho con ',
                style: TextStyle(fontSize: 12, color: tokens.textTertiary),
              ),
              Text(
                'AllCommerce',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
