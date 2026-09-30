import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/theme/app_tokens.dart';
import 'package:all_commerce/core/widgets/app_avatar.dart';
import 'package:all_commerce/core/widgets/app_skeleton.dart';
import 'package:all_commerce/core/widgets/app_states.dart';
import 'package:all_commerce/core/widgets/floating_nav_bar.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StoreDirectoryView extends ConsumerStatefulWidget {
  const StoreDirectoryView({this.focusSearch = false, super.key});

  /// Focus the search field when the route is `/?focus=search`.
  final bool focusSearch;

  @override
  ConsumerState<StoreDirectoryView> createState() =>
      _StoreDirectoryViewState();
}

class _StoreDirectoryViewState
    extends ConsumerState<StoreDirectoryView> {
  final FocusNode _searchFocus = FocusNode();
  bool _animated = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final AsyncValue<List<TenantModel>> tenants =
        ref.watch(activeTenantsProvider);
    final String search = ref.watch(storeSearchProvider);
    final UserModel? profile =
        ref.watch(currentProfileProvider).value;
    final bool animate = !_animated;
    _animated = true;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Text(
                    profile == null
                        ? 'Hola'
                        : 'Hola, ${profile.fullName.split(' ').first}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Text(
                    '¿Qué vas a pedir hoy?',
                    style: TextStyle(
                      fontSize: 16,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    focusNode: _searchFocus,
                    decoration: const InputDecoration(
                      hintText: AppStrings.searchStores,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (String value) => ref
                        .read(storeSearchProvider.notifier)
                        .setQuery(value),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: tenants.when(
                    loading: () => const AppSkeletonList(
                      itemCount: 4,
                      itemHeight: 132,
                    ),
                    error: (Object error, StackTrace stack) =>
                        AppErrorState(
                      onRetry: () =>
                          ref.invalidate(activeTenantsProvider),
                    ),
                    data: (List<TenantModel> list) {
                      if (list.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.storefront_outlined,
                          title: AppStrings.noStoresYet,
                        );
                      }
                      final List<TenantModel> filtered =
                          filterTenants(list, search);
                      if (filtered.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.search_off_rounded,
                          title: AppStrings.noStoresFound,
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          FloatingNavBar.height,
                        ),
                        itemCount: filtered.length,
                        itemBuilder:
                            (BuildContext context, int index) {
                              final Widget card = _StoreCard(
                                tenant: filtered[index],
                              );
                              return animate
                                  ? card
                                      .animate()
                                      .fadeIn(
                                        duration: 300.ms,
                                        delay:
                                            (index * 40).ms,
                                      )
                                      .slideY(
                                        begin: 0.08,
                                        end: 0,
                                        duration: 300.ms,
                                        delay:
                                            (index * 40).ms,
                                        curve: Curves.easeOutCubic,
                                      )
                                  : card;
                            },
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

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.tenant});

  final TenantModel tenant;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/s/${tenant.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 96,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: tenant.logoUrl == null
                        ? Container(color: tenant.primaryColorValue)
                        : CachedNetworkImage(
                            imageUrl: tenant.logoUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              color: tenant.primaryColorValue,
                            ),
                          ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: -20,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tokens.surface,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: AppAvatar(tenant: tenant, size: 56),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tenant.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: tokens.textPrimary,
                    ),
                  ),
                  if (tenant.description != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      tenant.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (tenant.address != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: tokens.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tenant.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
