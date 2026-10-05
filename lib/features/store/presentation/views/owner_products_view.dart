import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
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
    final AppTokens tokens = context.tokens;
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    final String? tenantId = profile?.tenantId;
    if (tenantId == null) {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.storefront_outlined,
          title: AppStrings.storeNotFound,
        ),
      );
    }
    final AsyncValue<TenantModel?> tenantAsync = ref.watch(
      tenantByIdProvider(tenantId),
    );
    final AsyncValue<List<ProductModel>> productsAsync = ref.watch(
      ownerProductsProvider(tenantId),
    );
    final TenantModel? tenant = tenantAsync.value;
    final int count = productsAsync.value?.length ?? 0;
    final int max = tenant?.plan.maxProducts ?? 0;
    final bool nearLimit = max > 0 && count / max >= 0.9;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Productos',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (tenant != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: nearLimit
                                ? tokens.danger.withValues(alpha: 0.1)
                                : tokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count / $max',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: nearLimit
                                  ? tokens.danger
                                  : tokens.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _FilterSegmented(),
                ),
                const SizedBox(height: 4),
                Expanded(child: _ProductList(tenantId: tenantId)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSegmented extends ConsumerWidget {
  const _FilterSegmented();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final OwnerFilter filter = ref.watch(ownerFilterProvider);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: SegmentedButton<OwnerFilter>(
        showSelectedIcon: false,
        segments: const <ButtonSegment<OwnerFilter>>[
          ButtonSegment<OwnerFilter>(
            value: OwnerFilter.all,
            label: Text('Todos'),
          ),
          ButtonSegment<OwnerFilter>(
            value: OwnerFilter.active,
            label: Text('Activos'),
          ),
          ButtonSegment<OwnerFilter>(
            value: OwnerFilter.paused,
            label: Text('Pausados'),
          ),
        ],
        selected: <OwnerFilter>{filter},
        onSelectionChanged: (Set<OwnerFilter> selection) =>
            ref.read(ownerFilterProvider.notifier).setFilter(selection.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? tokens.surface
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? tokens.textPrimary
                : tokens.textSecondary,
          ),
          side: WidgetStateProperty.resolveWith(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? BorderSide(color: tokens.border)
                : BorderSide.none,
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
        ),
      ),
    );
  }
}

class _ProductList extends ConsumerWidget {
  const _ProductList({required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProductModel>> productsAsync = ref.watch(
      ownerProductsProvider(tenantId),
    );
    final String query = ref.watch(ownerProductQueryProvider);
    final OwnerFilter filter = ref.watch(ownerFilterProvider);
    return productsAsync.when(
      loading: () => const AppSkeletonList(itemCount: 6, itemHeight: 72),
      error: (Object error, StackTrace stack) => AppErrorState(
        onRetry: () => ref.invalidate(ownerProductsProvider(tenantId)),
      ),
      data: (List<ProductModel> products) {
        if (products.isEmpty) {
          return AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Todavía no cargaste productos',
            actionLabel: 'Subir el primero',
            onAction: () => context.push('/owner/products/new'),
          );
        }
        final List<ProductModel> filtered = filterOwnerProducts(
          products,
          query: query,
          filter: filter,
        );
        if (filtered.isEmpty) {
          return AppEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Sin resultados',
            actionLabel: AppStrings.clearFilters,
            onAction: () {
              ref.read(ownerProductQueryProvider.notifier).setQuery('');
              ref.read(ownerFilterProvider.notifier).setFilter(OwnerFilter.all);
            },
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(ownerProductsProvider(tenantId)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              FloatingNavBar.height,
            ),
            itemCount: filtered.length,
            separatorBuilder: (BuildContext context, int index) =>
                Divider(height: 1, color: context.tokens.border),
            itemBuilder: (BuildContext context, int index) =>
                _OwnerProductRow(product: filtered[index]),
          ),
        );
      },
    );
  }
}

class _OwnerProductRow extends ConsumerWidget {
  const _OwnerProductRow({required this.product});

  final ProductModel product;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showAppConfirmSheet(
      context,
      title: '¿Eliminar «${product.title}»?',
      message: 'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final bool ok = await ref
        .read(ownerInventoryControllerProvider.notifier)
        .delete(product);
    if (!context.mounted) return;
    if (ok) {
      showAppSnackBar(context, 'Producto eliminado');
    } else {
      final Object? error = ref.read(ownerInventoryControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final String? busyId = ref
        .watch(ownerInventoryControllerProvider)
        .busyProductId;
    final bool paused = !product.isActive;
    return InkWell(
      onTap: () =>
          context.push('/owner/products/${product.id}/edit', extra: product),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Opacity(
              opacity: paused ? 0.5 : 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: product.imageUrl == null
                      ? Container(
                          color: tokens.surfaceMuted,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 20,
                            color: tokens.textTertiary,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (BuildContext context, String url, _) =>
                              Container(
                                color: tokens.surfaceMuted,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 20,
                                  color: tokens.textTertiary,
                                ),
                              ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: paused ? tokens.textTertiary : tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.sku == null ? '' : '${product.sku} · '}'
                    'Stock ${product.stock}',
                    style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                  ),
                ],
              ),
            ),
            Text(
              Formatters.price(product.price),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: paused ? tokens.textTertiary : tokens.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: product.isActive,
                onChanged: busyId == product.id
                    ? null
                    : (_) async {
                        final bool ok = await ref
                            .read(ownerInventoryControllerProvider.notifier)
                            .toggleActive(product);
                        if (!ok && context.mounted) {
                          final Object? error = ref
                              .read(ownerInventoryControllerProvider)
                              .error;
                          if (error != null) {
                            showErrorSnackBar(context, error);
                          }
                        }
                      },
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opciones',
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: tokens.textSecondary,
              ),
              onSelected: (String value) {
                if (value == 'edit') {
                  context.push(
                    '/owner/products/${product.id}/edit',
                    extra: product,
                  );
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
      ),
    );
  }
}
