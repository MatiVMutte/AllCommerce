import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/auth/presentation/widgets/auth_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RoleSelectView extends ConsumerWidget {
  const RoleSelectView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const AuthHeader(
                    title: '¿Cómo vas a usar AllCommerce?',
                    subtitle: 'Elegí una opción para continuar',
                  ),
                  const SizedBox(height: 28),
                  _RoleCard(
                    icon: Icons.storefront_outlined,
                    title: 'Soy dueño de un local',
                    subtitle:
                        'Subo productos y recibo pedidos por WhatsApp',
                    onTap: () => context.go('/onboarding/business'),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Soy cliente',
                    subtitle: 'Exploro catálogos y hago pedidos',
                    onTap: () => context.go('/onboarding/customer'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .signOut(),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.1),
                ),
                child: Icon(icon, size: 26, color: primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
