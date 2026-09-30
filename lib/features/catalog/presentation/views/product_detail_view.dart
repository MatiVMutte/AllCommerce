import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_haptics.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/utils/share_service.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/quantity_stepper.dart';
import 'package:all_commerce/features/cart/presentation/widgets/add_to_cart.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    final AsyncValue<TenantModel?> tenantAsync =
        ref.watch(tenantBySlugProvider(slug));
    return tenantAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
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
      text: '${product.title} — ${Formatters.price(product.price)} '
          'en ${tenant.name}',
    );
    if (context.mounted && result == ShareResult.copied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copiado')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final AsyncValue<ProductModel?> productAsync = ref.watch(
      productByIdProvider((tenantId: tenant.id, productId: productId)),
    );
    return Scaffold(
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => AppErrorState(
          onRetry: () => ref.invalidate(
            productByIdProvider(
              (tenantId: tenant.id, productId: productId),
            ),
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
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/s/$slug'),
                  ),
                  _CircleButton(
                    icon: Icons.share_outlined,
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
                builder:
                    (BuildContext context, BoxConstraints constraints) {
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
                          padding: EdgeInsets.only(
                            top: imageHeight - 28,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .scaffoldBackgroundColor,
                              borderRadius:
                                  const BorderRadius.vertical(
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
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

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
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product, required this.tokens});

  final ProductModel product;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final Widget child = product.imageUrl == null
        ? Container(
            color: tokens.surfaceMuted,
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 64,
              color: tokens.textTertiary,
            ),
          )
        : CachedNetworkImage(
            imageUrl: product.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: tokens.surfaceMuted),
            errorWidget: (_, _, _) => Container(
              color: tokens.surfaceMuted,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 64,
                color: tokens.textTertiary,
              ),
            ),
          );
    return Hero(tag: 'product-${product.id}', child: child);
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
  int _quantity = 1;

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
                  product.categoryEnum.label,
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
                style:
                    Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
              ),
              const SizedBox(height: 8),
              Text(
                Formatters.price(product.price),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (product.stock <= 0)
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
              else if (product.stock <= 3)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Últimas ${product.stock} unidades',
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
                  onChanged: (int qty) =>
                      setState(() => _quantity = qty),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: product.stock <= 0
                        ? null
                        : () {
                            AppHaptics.medium();
                            addToCartWithConfirm(
                              context,
                              ref,
                              product,
                              widget.tenant,
                              quantity: _quantity,
                            );
                          },
                    child: Text(
                      'Agregar · '
                      '${Formatters.price(product.price * _quantity)}',
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
