import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/product_upload/presentation/widgets/plan_blocked_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OwnerHomeView extends ConsumerWidget {
  const OwnerHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UserModel?> profileAsync =
        ref.watch(currentProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi local')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            const Center(child: Text('Ocurrió un error. Intentá de nuevo.')),
        data: (UserModel? profile) {
          final String? tenantId = profile?.tenantId;
          if (tenantId == null) {
            return const Center(child: Text('No encontramos tu local.'));
          }
          final AsyncValue<TenantModel?> tenantAsync =
              ref.watch(tenantByIdProvider(tenantId));
          return tenantAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stack) => const Center(
              child: Text('Ocurrió un error. Intentá de nuevo.'),
            ),
            data: (TenantModel? tenant) {
              if (tenant == null) {
                return const Center(child: Text('No encontramos tu local.'));
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        tenant.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Tu link: allcommerce.app/s/${tenant.slug}'),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          '${tenant.plan.label} · ${tenant.daysLeft} días restantes',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Subir producto'),
                        onPressed: tenant.canPublish
                            ? () => context.go('/owner/products/new')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.go('/s/${tenant.slug}'),
                        child: const Text('Ver mi catálogo'),
                      ),
                      if (!tenant.canPublish) ...<Widget>[
                        const SizedBox(height: 24),
                        PlanBlockedCard(
                          code: 'PLAN_EXPIRED',
                          tenant: tenant,
                        ),
                      ],
                      TextButton(
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .signOut(),
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
