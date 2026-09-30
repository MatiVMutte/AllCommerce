import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/view_models/owner_orders_providers.dart';
import 'package:all_commerce/features/product_upload/presentation/widgets/plan_blocked_card.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                return const Center(
                  child: Text('No encontramos tu local.'),
                );
              }
              return _OwnerPanel(tenant: tenant);
            },
          );
        },
      ),
    );
  }
}

class _OwnerPanel extends ConsumerWidget {
  const _OwnerPanel({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<ProductModel>? products =
        ref.watch(ownerProductsProvider(tenant.id)).value;
    final List<OrderModel>? orders =
        ref.watch(ownerOrdersProvider(tenant.id)).value;
    final int pending = orders == null ? 0 : pendingCount(orders);
    final bool warning =
        tenant.canPublish && tenant.daysLeft <= 3;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + FloatingNavBar.height,
          ),
          children: <Widget>[
            if (!tenant.canPublish)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PlanBlockedCard(
                  code: 'PLAN_EXPIRED',
                  tenant: tenant,
                ),
              ),
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 32,
                  backgroundColor: tenant.primaryColorValue,
                  foregroundColor: Colors.white,
                  child: tenant.logoUrl == null
                      ? Text(
                          tenant.name.characters.first.toUpperCase(),
                          style: const TextStyle(fontSize: 24),
                        )
                      : ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: tenant.logoUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Text(
                              tenant.name.characters.first.toUpperCase(),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        tenant.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(
                          '${tenant.plan.label} · '
                          '${tenant.daysLeft} días',
                        ),
                        backgroundColor: warning
                            ? scheme.errorContainer
                            : null,
                        labelStyle: warning
                            ? TextStyle(
                                color: scheme.onErrorContainer,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Tu link: allcommerce.app/s/${tenant.slug}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  tooltip: 'Copiar link',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: 'allcommerce.app/s/${tenant.slug}',
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copiado'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount:
                  MediaQuery.of(context).size.width >= 600 ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: <Widget>[
                _NavCard(
                  icon: Icons.add_a_photo_outlined,
                  title: 'Subir producto',
                  onTap: tenant.canPublish
                      ? () => context.push('/owner/products/new')
                      : null,
                ),
                _NavCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Mis productos',
                  subtitle: products == null
                      ? null
                      : '${products.length} / '
                          '${tenant.plan.maxProducts} productos',
                  onTap: () => context.push('/owner/products'),
                ),
                _NavCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Pedidos',
                  subtitle: pending > 0 ? '$pending nuevos' : null,
                  badgeCount: pending,
                  onTap: () => context.push('/owner/orders'),
                ),
                _NavCard(
                  icon: Icons.settings_outlined,
                  title: 'Configuración',
                  onTap: () => context.push('/owner/settings'),
                ),
                _NavCard(
                  icon: Icons.storefront_outlined,
                  title: 'Ver mi catálogo',
                  onTap: () => context.push('/s/${tenant.slug}'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badgeCount = 0,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int badgeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text('$badgeCount'),
                child: Icon(icon),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
