import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/tenant/tenant_strategy.dart';
import 'package:all_commerce/features/catalog/presentation/views/catalog_view.dart';
import 'package:all_commerce/features/catalog/presentation/views/store_directory_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>(
  (Ref ref) => GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const StoreDirectoryView(),
      ),
      GoRoute(
        path: '/s/:slug',
        builder: (BuildContext context, GoRouterState state) =>
            CatalogView(slug: state.pathParameters['slug'] ?? ''),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      // Build white-label (TENANT_SLUG fijo): la raíz es el catálogo del local.
      final TenantResolver resolver = ref.read(tenantResolverProvider);
      if (resolver.isWhiteLabel && state.matchedLocation == '/') {
        return '/s/${resolver.fixedSlug}';
      }
      // Guards de sesión/rol: Fase 2
      return null;
    },
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(AppStrings.pageNotFound),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text(AppStrings.backToHome),
            ),
          ],
        ),
      ),
    ),
  ),
);
