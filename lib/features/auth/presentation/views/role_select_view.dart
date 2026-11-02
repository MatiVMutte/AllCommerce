import 'package:all_commerce/core/theme/app_brand.dart';
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
    return AuthScaffold(
      showBack: false,
      useCard: false,
      maxWidth: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AuthHeader(
            title: '¿Cómo vas a usar ALLCommerce?',
            subtitle:
                'Elegí una opción para continuar. Después '
                'podés abrir tu local desde tu perfil.',
          ),
          const SizedBox(height: 28),
          _RoleCard(
            icon: Icons.storefront_outlined,
            title: 'Soy dueño de un local',
            subtitle: 'Subo productos y recibo pedidos por WhatsApp',
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
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
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
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: <Widget>[
              BrandIconBadge(icon: icon, size: 56),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.surfaceMuted,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
