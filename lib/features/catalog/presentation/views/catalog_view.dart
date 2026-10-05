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
import 'package:all_commerce/features/cart/data/models/cart_state.dart';
import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/features/cart/presentation/widgets/add_to_cart.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
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
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchChipsHeader(
                    tokens: tokens,
                    filter: filter,
                    products: productsAsync.value ?? const <ProductModel>[],
                    onQuery: (String q) => ref
                        .read(catalogFilterProvider(slug).notifier)
                        .setQuery(q),
                    onCategory: (ProductCategory c) => ref
                        .read(catalogFilterProvider(slug).notifier)
                        .setCategory(c),
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
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) => _ProductCard(
                              slug: slug,
                              product: filtered[index],
                              tenant: tenant,
                            ),
                            childCount: filtered.length,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    MediaQuery.of(context).size.width < 600
                                    ? 2
                                    : MediaQuery.of(context).size.width < 1000
                                    ? 3
                                    : 4,
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
                const SliverPadding(
                  padding: EdgeInsets.only(bottom: FloatingNavBar.height),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              const SizedBox(height: 8),
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
    required this.onClear,
  });

  final AppTokens tokens;
  final CatalogFilter filter;
  final List<ProductModel> products;
  final ValueChanged<String> onQuery;
  final ValueChanged<ProductCategory> onCategory;
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
    final Set<ProductCategory> present = products
        .map((ProductModel p) => p.categoryEnum)
        .toSet();
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
                  selected: filter.category == null,
                  onTap: onClear,
                ),
                for (final ProductCategory category in present)
                  _CategoryChip(
                    label: category.label,
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
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
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Theme.of(context).scaffoldBackgroundColor
                  : tokens.textPrimary,
            ),
          ),
        ),
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
    for (final item in cart.items) {
      if (cart.tenantId == tenant.id && item.productId == product.id) {
        inCart = item.quantity;
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
                      CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: tokens.surfaceMuted),
                        errorWidget: (_, _, _) => Container(
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
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: PricePill(price: product.price),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: inCart > 0
                          ? Container(
                              decoration: BoxDecoration(
                                color: tokens.surface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: QuantityStepper(
                                dense: true,
                                quantity: inCart,
                                onChanged: (int qty) => ref
                                    .read(cartProvider.notifier)
                                    .setQuantity(product.id, qty),
                              ),
                            )
                          : _AddButton(
                              onTap: () {
                                AppHaptics.light();
                                addToCartWithConfirm(
                                  context,
                                  ref,
                                  product,
                                  tenant,
                                );
                              },
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
      ],
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.onTap});

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
