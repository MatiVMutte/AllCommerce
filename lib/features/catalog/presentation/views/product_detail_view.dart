import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/tenant/tenant_theme.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/widgets/app_snackbar.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/quantity_stepper.dart';
import 'package:all_commerce/features/cart/presentation/view_models/cart_controller.dart';
import 'package:all_commerce/features/cart/presentation/widgets/add_to_cart.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/core/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProductDetailView extends ConsumerWidget {
  const ProductDetailView({
    required this.slug,
    required this.productId,
    super.key,
  });

  final String slug;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TenantModel?> tenantAsync = ref.watch(
      tenantBySlugProvider(slug),
    );
    return tenantAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
        return _ProductDetailScaffold(
          slug: slug,
          tenant: tenant,
          productId: productId,
        );
      },
    );
  }
}

class _ProductDetailScaffold extends ConsumerWidget {
  const _ProductDetailScaffold({
    required this.slug,
    required this.tenant,
    required this.productId,
  });

  final String slug;
  final TenantModel tenant;
  final String productId;

  Future<void> _share(BuildContext context, ProductModel product) async {
    final ShareResult result = await const ShareService().shareLink(
      url: ShareService.productUrl(slug, product.id),
      text:
          '${product.title} — ${Formatters.price(product.price)} '
          'en ${tenant.name}',
    );
    if (context.mounted && result == ShareResult.copied) {
      showAppSnackBar(context, 'Link copiado', clearNavBar: false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final AsyncValue<ProductModel?> productAsync = ref.watch(
      productByIdProvider((tenantId: tenant.id, productId: productId)),
    );
    return TenantTheme(
      brandColor: tenant.primaryColorValue,
      child: Scaffold(
        body: productAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) => AppErrorState(
            onRetry: () => ref.invalidate(
              productByIdProvider((tenantId: tenant.id, productId: productId)),
            ),
          ),
          data: (ProductModel? product) {
            if (product == null) {
              return AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: AppStrings.productNotFound,
                actionLabel: AppStrings.backToCatalog,
                onAction: () => context.go('/s/$slug'),
              );
            }
            final Widget image = _ProductImage(
              product: product,
              tokens: tokens,
            );
            final Widget overlayButtons = SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _CircleButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Volver',
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/s/$slug'),
                    ),
                    _CircleButton(
                      icon: Icons.share_outlined,
                      tooltip: 'Compartir producto',
                      onTap: () => _share(context, product),
                    ),
                  ],
                ),
              ),
            );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool wide = constraints.maxWidth >= 800;
                    if (wide) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: <Widget>[
                                      image,
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: overlayButtons,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              child: _ProductPanel(
                                slug: slug,
                                product: product,
                                tenant: tenant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final double imageHeight =
                        MediaQuery.of(context).size.height * 0.45;
                    return Stack(
                      children: <Widget>[
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: imageHeight,
                          child: image,
                        ),
                        Positioned.fill(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(top: imageHeight - 28),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .scaffoldBackgroundColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(28),
                                ),
                              ),
                              child: _ProductPanel(
                                slug: slug,
                                product: product,
                                tenant: tenant,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: overlayButtons,
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: context.tokens.overlay.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
      ),
    );
  }
}

class _ProductImage extends StatefulWidget {
  const _ProductImage({required this.product, required this.tokens});

  final ProductModel product;
  final AppTokens tokens;

  @override
  State<_ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<_ProductImage> {
  int _page = 0;

  Widget _fallback() {
    return Container(
      color: widget.tokens.surfaceMuted,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 64,
        color: widget.tokens.textTertiary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> urls = widget.product.gallery;
    if (urls.isEmpty) {
      return Hero(tag: 'product-${widget.product.id}', child: _fallback());
    }
    if (urls.length == 1) {
      return Hero(
        tag: 'product-${widget.product.id}',
        child: AppNetworkImage(
          imageUrl: urls.first,
          placeholder: Container(color: widget.tokens.surfaceMuted),
          errorBuilder: (_) => _fallback(),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          itemCount: urls.length,
          onPageChanged: (int i) => setState(() => _page = i),
          itemBuilder: (BuildContext context, int i) => AppNetworkImage(
            imageUrl: urls[i],
            placeholder: Container(color: widget.tokens.surfaceMuted),
            errorBuilder: (_) => _fallback(),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < urls.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: 64,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_page + 1}/${urls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductPanel extends ConsumerStatefulWidget {
  const _ProductPanel({
    required this.slug,
    required this.product,
    required this.tenant,
  });

  final String slug;
  final ProductModel product;
  final TenantModel tenant;

  @override
  ConsumerState<_ProductPanel> createState() => _ProductPanelState();
}

class _ProductPanelState extends ConsumerState<_ProductPanel> {
  double _quantity = 1;
  String? _variant;
  bool _justAdded = false;

  @override
  void initState() {
    super.initState();
    _variant = widget.product.variants.isEmpty
        ? null
        : widget.product.variants.first;
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final ProductModel product = widget.product;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  product.categoryLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.title,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: <Widget>[
                  Text(
                    Formatters.price(product.price),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (product.isOnSale) ...<Widget>[
                    Text(
                      Formatters.price(product.compareAtPrice!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: tokens.textTertiary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.success.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '-${product.discountPercent}% OFF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (product.hasWholesale)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Mayorista: ${Formatters.price(product.wholesalePrice!)} '
                          'c/u llevando ${product.wholesaleMinQty} o más',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (product.hasVariants) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'Elegí una opción',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String v in product.variants)
                      ChoiceChip(
                        label: Text(v),
                        selected: _variant == v,
                        onSelected: (_) => setState(() => _variant = v),
                      ),
                  ],
                ),
              ],
              if (product.isOutOfStock)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Sin stock',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.danger,
                    ),
                  ),
                )
              else if (product.isLowStock)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Últimas ${Formatters.qtyLabel(product.stock, product.unit)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.warning,
                    ),
                  ),
                ),
              if (product.description != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  product.description!,
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ],
              if (product.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: product.tags
                      .map(
                        (String tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border(top: BorderSide(color: tokens.border)),
            ),
            child: Row(
              children: <Widget>[
                QuantityStepper(
                  quantity: _quantity,
                  maxQuantity: product.trackStock ? product.stock : null,
                  step: product.isFractional ? 0.25 : 1,
                  unit: product.unit,
                  onChanged: (double qty) {
                    final double min = product.isFractional ? 0.25 : 1;
                    if (qty < min) return;
                    if (product.trackStock && qty > product.stock) return;
                    setState(() => _quantity = qty);
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    style: _justAdded
                        ? FilledButton.styleFrom(
                            backgroundColor: tokens.success,
                          )
                        : null,
                    onPressed: product.isOutOfStock
                        ? null
                        : () async {
                            AppHaptics.medium();
                            final double before = ref
                                .read(cartProvider)
                                .items
                                .fold<double>(
                                  0,
                                  (double s, i) => s + i.quantity,
                                );
                            await addToCartWithConfirm(
                              context,
                              ref,
                              product,
                              widget.tenant,
                              quantity: _quantity,
                              variant: _variant,
                            );
                            if (!mounted) return;
                            final double after = ref
                                .read(cartProvider)
                                .items
                                .fold<double>(
                                  0,
                                  (double s, i) => s + i.quantity,
                                );
                            if (after != before) {
                              setState(() => _justAdded = true);
                              Future<void>.delayed(
                                const Duration(milliseconds: 1100),
                                () {
                                  if (mounted) {
                                    setState(() => _justAdded = false);
                                  }
                                },
                              );
                            }
                          },
                    child: Text(
                      product.isOutOfStock
                          ? 'Sin stock'
                          : _justAdded
                          ? '¡Agregado!'
                          : 'Agregar · '
                                '${Formatters.price(product.unitPriceFor(_quantity) * _quantity)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
