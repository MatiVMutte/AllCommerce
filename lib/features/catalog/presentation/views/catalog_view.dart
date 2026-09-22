import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/constants/categories.dart';
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

class CatalogView extends ConsumerWidget {
  const CatalogView({required this.slug, super.key});

  final String slug;

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
          child: _CatalogScaffold(slug: slug, tenant: tenant),
        );
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
    final AsyncValue<List<ProductModel>> productsAsync =
        ref.watch(catalogProductsProvider(tenant.id));
    final CatalogFilter filter = ref.watch(catalogFilterProvider(slug));
    final bool isWhiteLabel =
        ref.read(tenantResolverProvider).isWhiteLabel;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                title: Text(tenant.name),
                pinned: true,
                leading: isWhiteLabel
                    ? null
                    : BackButton(onPressed: () => context.go('/')),
              ),
              SliverToBoxAdapter(child: _StoreHeader(tenant: tenant)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: AppStrings.searchProducts,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (String value) => ref
                        .read(catalogFilterProvider(slug).notifier)
                        .setQuery(value),
                  ),
                ),
              ),
              ...productsAsync.when(
                loading: () => <Widget>[
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (Object error, StackTrace stack) => <Widget>[
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(AppStrings.genericError),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => ref.invalidate(
                              catalogProductsProvider(tenant.id),
                            ),
                            child: const Text(AppStrings.retry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                data: (List<ProductModel> products) {
                  if (products.isEmpty) {
                    return <Widget>[
                      const SliverFillRemaining(
                        child: Center(child: Text(AppStrings.noProductsYet)),
                      ),
                    ];
                  }
                  final Set<ProductCategory> present = products
                      .map((ProductModel p) => p.categoryEnum)
                      .toSet();
                  final List<ProductModel> filtered =
                      applyCatalogFilter(products, filter);
                  return <Widget>[
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: const Text(AppStrings.allCategories),
                                selected: filter.category == null,
                                onSelected: (_) => ref
                                    .read(
                                      catalogFilterProvider(slug).notifier,
                                    )
                                    .clear(),
                              ),
                            ),
                            for (final ProductCategory category in present)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(category.label),
                                  selected: filter.category == category,
                                  onSelected: (_) => ref
                                      .read(
                                        catalogFilterProvider(slug).notifier,
                                      )
                                      .setCategory(category),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Text(AppStrings.noProductsFound),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => ref
                                    .read(
                                      catalogFilterProvider(slug).notifier,
                                    )
                                    .clear(),
                                child: const Text(AppStrings.clearFilters),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) =>
                              _ProductCard(
                                slug: slug,
                                product: filtered[index],
                              ),
                          childCount: filtered.length,
                        ),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  MediaQuery.of(context).size.width < 600
                                      ? 2
                                      : MediaQuery.of(context).size.width <
                                              900
                                          ? 3
                                          : 4,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.66,
                            ),
                        ),
                      ),
                  ];
                },
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            tenant.primaryColorValue,
            tenant.primaryColorValue.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
          top: Radius.circular(16),
        ),
      ),
      child: Column(
        children: <Widget>[
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            foregroundColor: tenant.primaryColorValue,
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
                      errorWidget:
                          (BuildContext context, String url, _) => Text(
                            tenant.name.characters.first.toUpperCase(),
                            style: const TextStyle(fontSize: 24),
                          ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            tenant.name,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white),
          ),
          if (tenant.description != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              tenant.description!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
          if (tenant.address != null) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    tenant.address!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.slug, required this.product});

  final String slug;
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/s/$slug/p/${product.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: product.imageUrl == null
                  ? Container(
                      color: const Color(0xFFE3E7F3),
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        size: 40,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (BuildContext context, String url) =>
                          Container(color: const Color(0xFFE3E7F3)),
                      errorWidget:
                          (BuildContext context, String url, _) => Container(
                            color: const Color(0xFFE3E7F3),
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              size: 40,
                            ),
                          ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.price(product.price),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
