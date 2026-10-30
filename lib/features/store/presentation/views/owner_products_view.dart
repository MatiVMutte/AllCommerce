import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/snackbar.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/app_confirm_sheet.dart';
import 'package:all_commerce/core/widgets/app_refresh_button.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:all_commerce/features/product_upload/presentation/views/product_upload_view.dart';
import 'package:all_commerce/core/widgets/app_network_image.dart';
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

    final bool wide = AdaptiveNavShell.isWide(context);
    final String? selectedId = ref.watch(selectedOwnerProductProvider);
    final Widget listPane = Column(
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
              AppRefreshButton(
                onRefresh: () async {
                  ref.invalidate(ownerProductsProvider(tenantId));
                  await ref
                      .read(ownerProductsProvider(tenantId).future)
                      .catchError((Object _) => const <ProductModel>[]);
                },
              ),
              const SizedBox(width: 8),
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
                      color: nearLimit ? tokens.danger : tokens.textSecondary,
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
            onChanged: (String value) =>
                ref.read(ownerProductQueryProvider.notifier).setQuery(value),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/owner/products/bulk-upload'),
                  icon: const Icon(Icons.layers_outlined, size: 18),
                  label: const Text('Carga masiva'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => AdaptiveNavShell.isWide(context)
                      ? ref
                            .read(selectedOwnerProductProvider.notifier)
                            .select('new')
                      : context.push('/owner/products/new'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Subir uno'),
                ),
              ),
            ],
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
    );
    if (wide) {
      final ProductModel? selected = selectedId == null
          ? null
          : productsAsync.value
                ?.where((ProductModel p) => p.id == selectedId)
                .firstOrNull;
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Row(
            children: <Widget>[
              SizedBox(width: 430, child: listPane),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: selectedId == null
                    ? const AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Seleccioná un producto',
                        subtitle: 'Tocá uno de la lista o creá uno nuevo con "Subir uno".',
                      )
                    : ProductUploadView(
                        key: ValueKey<String>(selectedId),
                        existing: selectedId == 'new' ? null : selected,
                        embedded: true,
                        onClose: () => ref
                            .read(selectedOwnerProductProvider.notifier)
                            .select(null),
                      ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: listPane,
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
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              AdaptiveNavShell.isWide(context) ? 24 : FloatingNavBar.height,
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

  Future<void> _adjustStock(BuildContext context, WidgetRef ref) async {
    final int currentStock = product.stock;
    bool track = product.trackStock;
    final TextEditingController ctrl = TextEditingController(
      text: currentStock.toString(),
    );
    final ({int stock, bool track})?
    result = await showModalBottomSheet<({int stock, bool track})>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(context).bottom +
                    MediaQuery.viewPaddingOf(context).bottom +
                    20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Stock · ${product.title}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: track,
                    onChanged: (bool v) {
                      setSheetState(() {
                        track = v;
                        if (v && (int.tryParse(ctrl.text.trim()) ?? 0) <= 0) {
                          ctrl.text = '1';
                        }
                      });
                    },
                    title: const Text('Controlar stock disponible'),
                  ),
                  if (track) ...<Widget>[
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Unidades disponibles',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final int parsed = int.tryParse(ctrl.text.trim()) ?? 0;
                      Navigator.of(sheetContext)
                          .pop((stock: track ? parsed : 0, track: track));
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    ctrl.dispose();
    if (result == null || !context.mounted) return;
    final bool ok = await ref
        .read(ownerInventoryControllerProvider.notifier)
        .updateStock(product, stock: result.stock, trackStock: result.track);
    if (!context.mounted) return;
    if (ok) {
      showAppSnackBar(context, 'Stock actualizado');
    } else {
      final Object? error = ref.read(ownerInventoryControllerProvider).error;
      if (error != null) showErrorSnackBar(context, error);
    }
  }

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
    final bool wide = AdaptiveNavShell.isWide(context);
    return InkWell(
      onTap: () {
        if (wide) {
          ref.read(selectedOwnerProductProvider.notifier).select(product.id);
        } else {
          context.push('/owner/products/${product.id}/edit', extra: product);
        }
      },
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
                      : AppNetworkImage(
                          imageUrl: product.imageUrl!,
                          placeholder: Container(color: tokens.surfaceMuted),
                          errorBuilder: (_) => Container(
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
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        if (product.sku != null &&
                            product.sku!.trim().isNotEmpty)
                          TextSpan(
                            text: '${product.sku} · ',
                            style: TextStyle(color: tokens.textTertiary),
                          ),
                        TextSpan(
                          text: product.trackStock
                              ? (product.stock <= 0
                                    ? 'Agotado (0)'
                                    : 'Stock ${product.stock}')
                              : 'Stock ilimitado',
                          style: TextStyle(
                            fontWeight:
                                product.isOutOfStock || product.isLowStock
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: product.isOutOfStock
                                ? tokens.danger
                                : product.isLowStock
                                ? tokens.warning
                                : tokens.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (product.isOnSale)
                  Text(
                    Formatters.price(product.compareAtPrice!),
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textTertiary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Text(
                  Formatters.price(product.price),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: paused ? tokens.textTertiary : tokens.textPrimary,
                  ),
                ),
              ],
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
                } else if (value == 'stock') {
                  _adjustStock(context, ref);
                } else if (value == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                    PopupMenuItem<String>(
                      value: 'stock',
                      child: Text('Ajustar stock'),
                    ),
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
