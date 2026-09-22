import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_theme.dart';
import 'package:all_commerce/core/utils/formatters.dart';
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
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(AppStrings.genericError),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(tenantBySlugProvider(slug)),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
      data: (TenantModel? tenant) {
        if (tenant == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(AppStrings.storeNotFound),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text(AppStrings.backToHome),
                  ),
                ],
              ),
            ),
          );
        }
        return Theme(
          data: AppTheme.fromTenant(tenant),
          child: _ProductDetailScaffold(
            slug: slug,
            tenant: tenant,
            productId: productId,
          ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProductModel?> productAsync = ref.watch(
      productByIdProvider((tenantId: tenant.id, productId: productId)),
    );
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/s/$slug')),
        title: Text(tenant.name),
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(AppStrings.genericError),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(
                  productByIdProvider(
                    (tenantId: tenant.id, productId: productId),
                  ),
                ),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
        data: (ProductModel? product) {
          if (product == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(AppStrings.productNotFound),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/s/$slug'),
                    child: const Text(AppStrings.backToCatalog),
                  ),
                ],
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth >= 900;
                  final Widget image = AspectRatio(
                    aspectRatio: 1,
                    child: product.imageUrl == null
                        ? Container(
                            color: const Color(0xFFE3E7F3),
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              size: 64,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder:
                                (BuildContext context, String url) =>
                                    Container(
                                      color: const Color(0xFFE3E7F3),
                                    ),
                            errorWidget:
                                (BuildContext context, String url, _) =>
                                    Container(
                                      color: const Color(0xFFE3E7F3),
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 64,
                                      ),
                                    ),
                          ),
                  );
                  final Widget details =
                      _ProductDetails(product: product);
                  if (wide) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 480),
                            child: image,
                          ),
                          const SizedBox(width: 32),
                          Expanded(child: details),
                        ],
                      ),
                    );
                  }
                  return ListView(
                    children: <Widget>[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: image,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: details,
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

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Chip(label: Text(product.categoryEnum.label)),
        const SizedBox(height: 8),
        Text(
          product.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          Formatters.price(product.price),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        if (product.description != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(product.description!),
        ],
        if (product.tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: product.tags
                .map(
                  (String tag) => Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        const SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: null,
            child: Text(AppStrings.addToCart),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.comingSoon,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
