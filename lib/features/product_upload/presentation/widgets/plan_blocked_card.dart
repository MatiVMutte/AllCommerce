import 'package:all_commerce/core/constants/app_config.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class PlanBlockedCard extends StatelessWidget {
  const PlanBlockedCard({required this.code, required this.tenant, super.key});

  /// 'PLAN_EXPIRED' or 'PRODUCT_LIMIT_REACHED'.
  final String code;
  final TenantModel tenant;

  @override
  Widget build(BuildContext context) {
    final String whatsapp = AppConfig.supportWhatsapp;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_clock_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              code == 'PRODUCT_LIMIT_REACHED'
                  ? 'Llegaste al límite de tu plan'
                  : 'Tu prueba terminó',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Escribinos por WhatsApp y activamos tu plan en el día',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/owner/plans'),
              child: const Text('Ver planes'),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Escribir por WhatsApp'),
              onPressed: whatsapp.isEmpty
                  ? null
                  : () {
                      launchUrl(
                        Uri.parse(
                          'https://wa.me/$whatsapp?text='
                          '${Uri.encodeComponent('Hola! Quiero activar un plan de AllCommerce para mi local ${tenant.name} (${tenant.slug}).')}',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}
