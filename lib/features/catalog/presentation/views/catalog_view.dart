import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/constants/categories.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/widgets/app_avatar.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/core/widgets/made_with_all_commerce.dart';
import 'package:all_commerce/core/widgets/price_pill.dart';
import 'package:all_commerce/core/widgets/quantity_stepper.dart';
import 'package:all_commerce/features/cart/data/models/cart_item.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/features/cart/data/models/cart_state.dart';
import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/features/cart/presentation/widgets/add_to_cart.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/data/repositories/catalog_repository.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/app_network_image.dart';
import 'package:all_commerce/core/utils/app_motion.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CatalogView extends ConsumerWidget {
  const CatalogView({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TenantModel?> tenantAsync = ref.watch(
      tenantBySlugProvider(slug),
    );
    return tenantAsync.when(
      loading: () => const Scaffold(body: AppSkeletonGrid()),
      error: (Object error, StackTrace stack) => Scaffold(
        body: AppErrorState(
          onRetry: () => ref.invalidate(tenantBySlugProvider(slug)),
        ),
      ),
      data: (TenantModel? tenant) {
        if (tenant == null) {
          return Scaffold(
            body: AppEmptyState(
              icon: Icons.storefront_outlined,
              title: AppStrings.storeNotFound,
              actionLabel: AppStrings.backToHome,
              onAction: () => context.go('/'),
            ),
          );
        }
        return _CatalogScaffold(slug: slug, tenant: tenant);
      },
    );
  }
}

class _CatalogScaffold extends ConsumerWidget {
  const _CatalogScaffold({required this.slug, required this.tenant});

  final String slug;
  final TenantModel tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final AsyncValue<List<ProductModel>> productsAsync = ref.watch(
      catalogProductsProvider(tenant.id),
    );
    final CatalogFilter filter = ref.watch(catalogFilterProvider(slug));
    final bool isWhiteLabel = ref.read(tenantResolverProvider).isWhiteLabel;
    final Color brand = tenant.primaryColorValue;
    final Widget catalogBody = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(catalogProductsProvider(tenant.id)),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: brand,
                foregroundColor: Colors.white,
                leading: isWhiteLabel
                    ? null
                    : const _OverlayIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Volver',
                        fallback: '/',
                      ),
                title: Text(
                  tenant.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: <Widget>[
                  _OverlayIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Actualizar',
                    onPressed: () =>
                        ref.invalidate(catalogProductsProvider(tenant.id)),
                  ),
                  _OverlayIconButton(
                    icon: Icons.share_outlined,
                    tooltip: 'Compartir catálogo',
                    onPressed: () => _shareCatalog(context),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _StoreBanner(tenant: tenant),
                ),
              ),
              SliverToBoxAdapter(child: _CouponsBanner(tenantId: tenant.id)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchChipsHeader(
                  tokens: tokens,
                  filter: filter,
                  products: productsAsync.value ?? const <ProductModel>[],
                  onQuery: (String q) => ref
                      .read(catalogFilterProvider(slug).notifier)
                      .setQuery(q),
                  onCategory: (String c) => ref
                      .read(catalogFilterProvider(slug).notifier)
                      .setCategory(c),
                  onToggleOnSale: () => ref
                      .read(catalogFilterProvider(slug).notifier)
                      .toggleOnSale(),
                  onClear: () =>
                      ref.read(catalogFilterProvider(slug).notifier).clear(),
                ),
              ),
              ...productsAsync.when(
                loading: () => <Widget>[
                  const SliverFillRemaining(child: AppSkeletonGrid()),
                ],
                error: (Object error, StackTrace stack) => <Widget>[
                  SliverFillRemaining(
                    child: AppErrorState(
                      onRetry: () =>
                          ref.invalidate(catalogProductsProvider(tenant.id)),
                    ),
                  ),
                ],
                data: (List<ProductModel> products) {
                  if (products.isEmpty) {
                    return const <Widget>[
                      SliverFillRemaining(
                        child: AppEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: AppStrings.noProductsYet,
                        ),
                      ),
                    ];
                  }
                  final List<ProductModel> filtered = applyCatalogFilter(
                    products,
                    filter,
                  );
                  if (filtered.isEmpty) {
                    return <Widget>[
                      SliverFillRemaining(
                        child: AppEmptyState(
                          icon: Icons.search_off_rounded,
                          title: AppStrings.noProductsFound,
                          actionLabel: AppStrings.clearFilters,
                          onAction: () => ref
                              .read(catalogFilterProvider(slug).notifier)
                              .clear(),
                        ),
                      ),
                    ];
                  }
                  return <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((
                          BuildContext context,
                          int index,
                        ) {
                          final Widget card = _ProductCard(
                            slug: slug,
                            product: filtered[index],
                            tenant: tenant,
                          );
                          if (!AppMotion.enabled(context)) {
                            return card;
                          }
                          return FadeInUp(
                            duration: const Duration(milliseconds: 260),
                            delay: Duration(milliseconds: (index % 8) * 35),
                            from: 16,
                            child: card,
                          );
                        }, childCount: filtered.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width < 600
                              ? 2
                              : MediaQuery.of(context).size.width < 1000
                              ? 3
                              : MediaQuery.of(context).size.width < 1400
                              ? 4
                              : 5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.62,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: MadeWithAllCommerce(),
                      ),
                    ),
                  ];
                },
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: AdaptiveNavShell.isWide(context)
                      ? 24
                      : FloatingNavBar.height,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (AdaptiveNavShell.isWide(context)) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            Expanded(child: catalogBody),
            const VerticalDivider(width: 1, thickness: 1),
            SizedBox(
              width: 360,
              child: _CartSidePanel(slug: slug, tenant: tenant),
            ),
          ],
        ),
      );
    }
    return Scaffold(body: catalogBody);
  }

  Future<void> _shareCatalog(BuildContext context) async {
    final ShareResult result = await const ShareService().shareLink(
      url: ShareService.catalogUrl(slug),
      text: 'Mirá el catálogo de ${tenant.name}',
    );
    if (context.mounted && result == ShareResult.copied) {
      showAppSnackBar(context, 'Link copiado');
    }
  }
}

/// Semi-transparent circle button over the colored app bar / images.
class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    this.tooltip,
    this.fallback,
    this.onPressed,
  });

  final IconData icon;
  final String? tooltip;
  final String? fallback;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: tooltip,
          icon: Icon(icon, color: Colors.white, size: 20),
          onPressed:
              onPressed ??
              () {
                if (context.canPop()) {
                  context.pop();
                } else if (fallback != null) {
                  context.go(fallback!);
                }
              },
        ),
      ),
    );
  }
}

class _StoreBanner extends StatelessWidget {
  const _StoreBanner({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context) {
    final Color brand = tenant.primaryColorValue;
    final HSLColor hsl = HSLColor.fromColor(brand);
    final Color darker = hsl
        .withLightness((hsl.lightness * 0.85).clamp(0, 1))
        .toColor();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[brand, darker],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              AppAvatar(tenant: tenant, size: 64),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (tenant.isOpen
                                  ? Colors.green.shade700
                                  : Colors.black54)
                              .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tenant.isOpen ? 'Abierto' : 'Cerrado',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (tenant.openingHours != null &&
                      tenant.openingHours!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tenant.openingHours!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              if (tenant.address != null || tenant.whatsapp.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (tenant.address != null) ...<Widget>[
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          tenant.address!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      tenant.whatsapp,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky header with search pill + horizontal category chips.
class _SearchChipsHeader extends SliverPersistentHeaderDelegate {
  _SearchChipsHeader({
    required this.tokens,
    required this.filter,
    required this.products,
    required this.onQuery,
    required this.onCategory,
    required this.onToggleOnSale,
    required this.onClear,
  });

  final AppTokens tokens;
  final CatalogFilter filter;
  final List<ProductModel> products;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onCategory;
  final VoidCallback onToggleOnSale;
  final VoidCallback onClear;

  @override
  double get minExtent => 112;

  @override
  double get maxExtent => 112;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final Set<String> present = products
        .map((ProductModel p) => p.category)
        .toSet();
    final bool hasOnSale = products.any((ProductModel p) => p.isOnSale);
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: <Widget>[
          TextField(
            decoration: const InputDecoration(
              hintText: AppStrings.searchProducts,
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: onQuery,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                _CategoryChip(
                  label: AppStrings.allCategories,
                  selected: filter.category == null && !filter.onlyOnSale,
                  onTap: onClear,
                ),
                if (hasOnSale)
                  _CategoryChip(
                    label: 'Ofertas',
                    icon: Icons.local_offer_rounded,
                    selected: filter.onlyOnSale,
                    onTap: onToggleOnSale,
                  ),
                for (final String category in present)
                  _CategoryChip(
                    label: ProductCategory.labelOf(category),
                    selected: filter.category == category,
                    onTap: () => onCategory(category),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchChipsHeader oldDelegate) => true;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final Color fg = selected
        ? Theme.of(context).scaffoldBackgroundColor
        : tokens.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? tokens.textPrimary : tokens.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim strip under the header advertising the store's active coupons.
/// Tapping a code copies it so the customer can paste it in the cart.
class _CouponsBanner extends ConsumerWidget {
  const _CouponsBanner({required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final AsyncValue<List<PublicCoupon>> couponsAsync = ref.watch(
      activeCouponsProvider(tenantId),
    );
    final List<PublicCoupon> coupons =
        couponsAsync.value ?? const <PublicCoupon>[];
    if (coupons.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final PublicCoupon coupon in coupons)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: coupon.code));
                  showAppSnackBar(
                    context,
                    'Código ${coupon.code} copiado — pegalo en el carrito',
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tokens.success),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.local_offer_rounded,
                        size: 14,
                        color: tokens.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${coupon.code} · ${coupon.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Photo-forward product card: 3/4 image, price pill, + / stepper.
class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.slug,
    required this.product,
    required this.tenant,
  });

  final String slug;
  final ProductModel product;
  final TenantModel tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final CartState cart = ref.watch(cartProvider);
    int inCart = 0;
    String? inCartLineKey;
    for (final item in cart.items) {
      if (cart.tenantId == tenant.id && item.productId == product.id) {
        inCart = item.quantity;
        inCartLineKey = item.lineKey;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/s/$slug/p/${product.id}'),
            child: Hero(
              tag: 'product-${product.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (product.imageUrl == null)
                      Container(
                        color: tokens.surfaceMuted,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 40,
                          color: tokens.textTertiary,
                        ),
                      )
                    else
                      AppNetworkImage(
                        imageUrl: product.imageUrl!,
                        placeholder: Container(color: tokens.surfaceMuted),
                        errorBuilder: (_) => Container(
                          color: tokens.surfaceMuted,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: tokens.textTertiary,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 72,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.transparent,
                              tokens.overlay.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (product.isOnSale)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: ZoomIn(
                          duration: const Duration(milliseconds: 280),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.success,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '-${product.discountPercent}% OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (product.isOutOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.danger,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Agotado',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                    else if (product.isLowStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.warning,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Últimas ${product.stock}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: PricePill(
                        price: product.price,
                        compareAtPrice: product.compareAtPrice,
                      ),
                    ),
                    if (!product.isOutOfStock)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (
                            Widget child,
                            Animation<double> anim,
                          ) => ScaleTransition(scale: anim, child: child),
                          child: inCart > 0
                              ? Container(
                                  key: const ValueKey<String>('stepper'),
                                  decoration: BoxDecoration(
                                    color: tokens.surface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: QuantityStepper(
                                    dense: true,
                                    quantity: inCart,
                                    maxQuantity: product.trackStock
                                        ? product.stock
                                        : null,
                                    onChanged: (int qty) => ref
                                        .read(cartProvider.notifier)
                                        .setQuantity(
                                          inCartLineKey ?? product.id,
                                          qty,
                                        ),
                                  ),
                                )
                              : _AddButton(
                                  key: const ValueKey<String>('add'),
                                  onTap: () {
                                    AppHaptics.light();
                                    if (product.hasVariants) {
                                      context.push('/s/$slug/p/${product.id}');
                                      return;
                                    }
                                    addToCartWithConfirm(
                                      context,
                                      ref,
                                      product,
                                      tenant,
                                    );
                                  },
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 2, right: 2),
          child: Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: tokens.textPrimary,
            ),
          ),
        ),
        if (product.hasWholesale)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
            child: Text(
              'Mayor. ${Formatters.price(product.wholesalePrice!)} c/u '
              '(${product.wholesaleMinQty}+ u.)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _pressed = true);
        widget.onTap();
        Future<void>.delayed(const Duration(milliseconds: 180), () {
          if (mounted) setState(() => _pressed = false);
        });
      },
      child: Semantics(
        button: true,
        label: 'Agregar al carrito',
        child: AnimatedScale(
          scale: _pressed ? 0.85 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  blurRadius: 8,
                  offset: Offset(0, 2),
                  color: Color(0x33000000),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Persistent cart column shown on wide screens (master–detail style).
class _CartSidePanel extends ConsumerWidget {
  const _CartSidePanel({required this.slug, required this.tenant});

  final String slug;
  final TenantModel tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final cart = ref.watch(cartProvider);
    final double total = cart.items.fold<double>(
      0,
      (double s, CartItem i) => s + i.lineTotal,
    );
    return SafeArea(
      left: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Tu pedido',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Todavía no agregaste productos',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: tokens.border),
                    itemBuilder: (BuildContext context, int i) {
                      final CartItem item = cart.items[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.variant == null
                                        ? item.title
                                        : '${item.title} (${item.variant})',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    Formatters.price(item.lineTotal),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            QuantityStepper(
                              dense: true,
                              quantity: item.quantity,
                              onChanged: (int q) => ref
                                  .read(cartProvider.notifier)
                                  .setQuantity(item.lineKey, q),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.border)),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      Formatters.price(total),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Enviar pedido'),
                    onPressed: cart.items.isEmpty
                        ? null
                        : () => context.push('/s/$slug/cart'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
