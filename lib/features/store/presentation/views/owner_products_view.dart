import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/widgets/app_back_button.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OwnerProductsView extends ConsumerWidget {
  const OwnerProductsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;
    if (tenantId == null) {
      return const Scaffold(
        body: Center(child: Text(AppStrings.storeNotFound)),
      );
    }
    final AsyncValue<TenantModel?> tenantAsync =
        ref.watch(tenantByIdProvider(tenantId));
    final AsyncValue<List<ProductModel>> productsAsync =
        ref.watch(ownerProductsProvider(tenantId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis productos'),
        leading: const AppBackButton(fallback: '/owner'),
      ),
      floatingActionButton: tenantAsync.value == null
          ? null
          : _UploadFab(
              tenant: tenantAsync.value!,
              count: productsAsync.value?.length ?? 0,
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: <Widget>[
              if (tenantAsync.value != null)
                _UsageHeader(
                  tenant: tenantAsync.value!,
                  count: productsAsync.value?.length ?? 0,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: AppStrings.searchProducts,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (String value) => ref
                      .read(ownerProductQueryProvider.notifier)
                      .setQuery(value),
                ),
              ),
              _FilterChips(),
              Expanded(child: _ProductList(tenantId: tenantId)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageHeader extends StatelessWidget {
  const _UsageHeader({required this.tenant, required this.count});

  final TenantModel tenant;
  final int count;

  @override
  Widget build(BuildContext context) {
    final int max = tenant.plan.maxProducts;
    final double ratio = max == 0 ? 0 : count / max;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$count / $max productos'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            color: ratio >= 0.9
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OwnerFilter filter = ref.watch(ownerFilterProvider);
    Widget chip(String label, OwnerFilter value) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(label),
            selected: filter == value,
            onSelected: (_) =>
                ref.read(ownerFilterProvider.notifier).setFilter(value),
          ),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          chip('Todos', OwnerFilter.all),
          chip('Activos', OwnerFilter.active),
          chip('Pausados', OwnerFilter.paused),
        ],
      ),
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList({required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProductModel>> productsAsync =
        ref.watch(ownerProductsProvider(tenantId));
    final String query = ref.watch(ownerProductQueryProvider);
    final OwnerFilter filter = ref.watch(ownerFilterProvider);
    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(AppStrings.genericError),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(ownerProductsProvider(tenantId)),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
      data: (List<ProductModel> products) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Todavía no cargaste productos'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/owner/products/new'),
                  child: const Text('Subir el primero'),
                ),
              ],
            ),
          );
        }
        final List<ProductModel> filtered = filterOwnerProducts(
          products,
          query: query,
          filter: filter,
        );
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Sin resultados'),
                TextButton(
                  onPressed: () {
                    ref.read(ownerProductQueryProvider.notifier)
                        .setQuery('');
                    ref
                        .read(ownerFilterProvider.notifier)
                        .setFilter(OwnerFilter.all);
                  },
                  child: const Text(AppStrings.clearFilters),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding:
              const EdgeInsets.only(bottom: FloatingNavBar.height),
          itemCount: filtered.length,
          separatorBuilder: (BuildContext context, int index) =>
              const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) =>
              _OwnerProductTile(product: filtered[index]),
        );
      },
    );
  }
}

class _OwnerProductTile extends ConsumerWidget {
  const _OwnerProductTile({required this.product});

  final ProductModel product;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('¿Eliminar «${product.title}»?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final bool ok = await ref
        .read(ownerInventoryControllerProvider.notifier)
        .delete(product);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto eliminado')),
      );
    } else {
      final Object? error = ref.read(ownerInventoryControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? busyId =
        ref.watch(ownerInventoryControllerProvider).busyProductId;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: product.imageUrl == null
              ? Container(
                  color: const Color(0xFFE3E7F3),
                  child:
                      const Icon(Icons.image_not_supported_outlined),
                )
              : CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (BuildContext context, String url, _) =>
                      const Icon(Icons.image_not_supported_outlined),
                ),
        ),
      ),
      title: Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${Formatters.price(product.price)} · Stock: ${product.stock}',
          ),
          if (!product.isActive)
            const Chip(
              label: Text('Pausado'),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Switch(
            value: product.isActive,
            onChanged: busyId == product.id
                ? null
                : (_) async {
                    final bool ok = await ref
                        .read(ownerInventoryControllerProvider.notifier)
                        .toggleActive(product);
                    if (!ok && context.mounted) {
                      final Object? error =
                          ref.read(ownerInventoryControllerProvider).error;
                      if (error != null) {
                        showErrorSnackBar(context, error);
                      }
                    }
                  },
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'edit') {
                context.push('/owner/products/${product.id}/edit',
                    extra: product);
              } else if (value == 'delete') {
                _confirmDelete(context, ref);
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('Eliminar'),
              ),
            ],
          ),
        ],
      ),
      onTap: () =>
          context.push('/owner/products/${product.id}/edit', extra: product),
    );
  }
}

class _UploadFab extends StatelessWidget {
  const _UploadFab({required this.tenant, required this.count});

  final TenantModel tenant;
  final int count;

  @override
  Widget build(BuildContext context) {
    final bool atLimit = count >= tenant.plan.maxProducts;
    return FloatingActionButton.extended(
      icon: const Icon(Icons.add_a_photo_outlined),
      label: const Text(AppStrings.uploadProduct),
      onPressed: !tenant.canPublish
          ? null
          : () {
              if (atLimit) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Llegaste al límite de tu plan'),
                  ),
                );
                return;
              }
              context.push('/owner/products/new');
            },
    );
  }
}
