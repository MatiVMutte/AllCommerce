import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/utils/app_motion.dart';
import 'package:all_commerce/core/utils/formatters.dart';
import 'package:all_commerce/core/widgets/adaptive_nav_shell.dart';
import 'package:all_commerce/core/widgets/app_network_image.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/features/catalog/data/repositories/catalog_repository.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Ofertas" tab: every product on sale across all stores.
class OffersView extends ConsumerWidget {
  const OffersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTokens tokens = context.tokens;
    final AsyncValue<List<GlobalProductHit>> offersAsync = ref.watch(
      onSaleProductsProvider,
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Ofertas',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Descuentos de los locales de tu zona',
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: offersAsync.when(
                    loading: () => GridView.count(
                      crossAxisCount: 3,
                      padding: const EdgeInsets.all(16),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.72,
                      children: const <Widget>[
                        AppSkeleton(radius: 20),
                        AppSkeleton(radius: 20),
                        AppSkeleton(radius: 20),
                        AppSkeleton(radius: 20),
                        AppSkeleton(radius: 20),
                        AppSkeleton(radius: 20),
                      ],
                    ),
                    error: (Object e, StackTrace s) => AppErrorState(
                      onRetry: () => ref.invalidate(onSaleProductsProvider),
                    ),
                    data: (List<GlobalProductHit> offers) {
                      if (offers.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.local_offer_outlined,
                          title: 'Todavía no hay ofertas',
                          subtitle:
                              'Cuando un local publique un descuento '
                              'va a aparecer acá.',
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(onSaleProductsProvider),
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints box) {
                            final int columns = box.maxWidth >= 1280
                                ? 4
                                : box.maxWidth >= 980
                                ? 3
                                : 2;
                            final bool animate = AppMotion.enabled(context);
                            return GridView.builder(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                AdaptiveNavShell.isWide(context) ? 24 : 96,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.72,
                                  ),
                              itemCount: offers.length,
                              itemBuilder: (BuildContext context, int i) {
                                final Widget card = _OfferCard(hit: offers[i]);
                                if (!animate) return card;
                                return FadeInUp(
                                  duration: const Duration(milliseconds: 260),
                                  delay: Duration(milliseconds: (i % 8) * 40),
                                  from: 16,
                                  child: card,
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.hit});

  final GlobalProductHit hit;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final int? percent = hit.compareAtPrice == null || hit.price <= 0
        ? null
        : ((1 - hit.price / hit.compareAtPrice!) * 100).round();
    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/s/${hit.tenantSlug}/p/${hit.productId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  hit.imageUrl == null
                      ? Container(
                          color: tokens.surfaceMuted,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: tokens.textTertiary,
                          ),
                        )
                      : AppNetworkImage(
                          imageUrl: hit.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: Container(color: tokens.surfaceMuted),
                          errorBuilder: (_) => Container(
                            color: tokens.surfaceMuted,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: tokens.textTertiary,
                            ),
                          ),
                        ),
                  if (percent != null)
                    Positioned(
                      top: 8,
                      left: 8,
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
                          '-$percent% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hit.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Text(
                        Formatters.price(hit.price),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      if (hit.compareAtPrice != null) ...<Widget>[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            Formatters.price(hit.compareAtPrice!),
                            style: TextStyle(
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                              color: tokens.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: hit.tenantIsOpen
                            ? tokens.success
                            : tokens.textTertiary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          hit.tenantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
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
