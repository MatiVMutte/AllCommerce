import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/features/admin/presentation/views/admin_home_view.dart';
import 'package:all_commerce/features/admin/presentation/views/admin_plans_view.dart';
import 'package:all_commerce/features/admin/presentation/views/admin_tenant_view.dart';
import 'package:all_commerce/features/billing/presentation/views/plans_view.dart';
import 'package:all_commerce/core/router/customer_mode.dart';
import 'package:all_commerce/core/router/return_to.dart';
import 'package:all_commerce/core/router/router_refresh.dart';
import 'package:all_commerce/features/cart/presentation/views/cart_view.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/tenant/tenant_strategy.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/auth/presentation/views/customer_profile_view.dart';
import 'package:all_commerce/features/auth/presentation/views/forgot_password_view.dart';
import 'package:all_commerce/features/auth/presentation/views/login_view.dart';
import 'package:all_commerce/features/auth/presentation/views/profile_view.dart';
import 'package:all_commerce/features/auth/presentation/views/register_view.dart';
import 'package:all_commerce/features/auth/presentation/views/role_select_view.dart';
import 'package:all_commerce/features/auth/presentation/views/welcome_view.dart';
import 'package:all_commerce/features/catalog/presentation/views/catalog_view.dart';
import 'package:all_commerce/features/catalog/presentation/views/offers_view.dart';
import 'package:all_commerce/features/catalog/presentation/views/product_detail_view.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/legal/presentation/views/legal_view.dart';
import 'package:all_commerce/features/orders/data/models/order_model.dart';
import 'package:all_commerce/features/orders/presentation/views/my_orders_view.dart';
import 'package:all_commerce/features/orders/presentation/views/order_success_view.dart';
import 'package:all_commerce/features/orders/presentation/views/owner_order_detail_view.dart';
import 'package:all_commerce/features/orders/presentation/views/owner_orders_view.dart';
import 'package:all_commerce/features/product_upload/presentation/views/bulk_upload_view.dart';
import 'package:all_commerce/features/product_upload/presentation/views/product_upload_view.dart';
import 'package:all_commerce/features/store/presentation/views/owner_products_view.dart';
import 'package:all_commerce/features/store/presentation/views/tenant_settings_view.dart';
import 'package:all_commerce/features/store/presentation/views/product_edit_view.dart';
import 'package:all_commerce/features/catalog/presentation/views/store_directory_view.dart';
import 'package:all_commerce/features/store/presentation/views/business_onboarding_view.dart';
import 'package:all_commerce/features/shell/customer_shell.dart';
import 'package:all_commerce/features/shell/owner_shell.dart';
import 'package:all_commerce/features/store/presentation/views/owner_home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final RouterRefreshNotifier refreshNotifier = RouterRefreshNotifier(
    ref.read(authRepositoryProvider),
  );
  ref.onDispose(refreshNotifier.dispose);
  ref.listen(sessionProvider, (_, _) {
    refreshNotifier.refresh();
  });
  ref.listen(currentProfileProvider, (_, _) {
    refreshNotifier.refresh();
  });
  ref.listen(customerModeProvider, (_, _) {
    refreshNotifier.refresh();
  });
  return GoRouter(
    refreshListenable: refreshNotifier,
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            CustomerShell(state: state, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                StoreDirectoryView(
                  focusSearch: state.uri.queryParameters['focus'] == 'search',
                ),
          ),
          GoRoute(
            path: '/s/:slug',
            builder: (BuildContext context, GoRouterState state) =>
                CatalogView(slug: state.pathParameters['slug'] ?? ''),
          ),
          GoRoute(
            path: '/ofertas',
            builder: (BuildContext context, GoRouterState state) =>
                const OffersView(),
          ),
          GoRoute(
            path: '/my-orders',
            builder: (BuildContext context, GoRouterState state) =>
                const MyOrdersView(),
          ),
          GoRoute(
            path: '/profile',
            builder: (BuildContext context, GoRouterState state) =>
                const ProfileView(),
          ),
        ],
      ),
      GoRoute(
        path: '/s/:slug/cart',
        builder: (BuildContext context, GoRouterState state) =>
            CartView(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/s/:slug/order/:id',
        builder: (BuildContext context, GoRouterState state) =>
            OrderSuccessView(
              slug: state.pathParameters['slug'] ?? '',
              confirmation: state.extra is OrderConfirmation
                  ? state.extra! as OrderConfirmation
                  : null,
            ),
      ),
      GoRoute(
        path: '/s/:slug/p/:id',
        builder: (BuildContext context, GoRouterState state) =>
            ProductDetailView(
              slug: state.pathParameters['slug'] ?? '',
              productId: state.pathParameters['id'] ?? '',
            ),
      ),
      GoRoute(
        path: '/welcome',
        builder: (BuildContext context, GoRouterState state) =>
            const WelcomeView(),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginView(),
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterView(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordView(),
      ),
      GoRoute(
        path: '/terms',
        builder: (BuildContext context, GoRouterState state) =>
            const TermsView(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (BuildContext context, GoRouterState state) =>
            const PrivacyView(),
      ),
      GoRoute(
        path: '/select-role',
        builder: (BuildContext context, GoRouterState state) =>
            const RoleSelectView(),
      ),
      GoRoute(
        path: '/onboarding/customer',
        builder: (BuildContext context, GoRouterState state) =>
            const CustomerProfileView(),
      ),
      GoRoute(
        path: '/onboarding/business',
        builder: (BuildContext context, GoRouterState state) =>
            const BusinessOnboardingView(),
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            OwnerShell(state: state, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/owner',
            builder: (BuildContext context, GoRouterState state) =>
                const OwnerHomeView(),
          ),
          GoRoute(
            path: '/owner/products',
            builder: (BuildContext context, GoRouterState state) =>
                const OwnerProductsView(),
          ),
          GoRoute(
            path: '/owner/orders',
            builder: (BuildContext context, GoRouterState state) =>
                const OwnerOrdersView(),
          ),
          GoRoute(
            path: '/owner/settings',
            builder: (BuildContext context, GoRouterState state) =>
                const TenantSettingsView(),
          ),
        ],
      ),
      GoRoute(
        path: '/owner/plans',
        builder: (BuildContext context, GoRouterState state) =>
            const PlansView(),
      ),
      GoRoute(
        path: '/admin',
        builder: (BuildContext context, GoRouterState state) =>
            const AdminHomeView(),
      ),
      GoRoute(
        path: '/admin/tenants/:id',
        builder: (BuildContext context, GoRouterState state) =>
            AdminTenantView(tenantId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/admin/plans',
        builder: (BuildContext context, GoRouterState state) =>
            const AdminPlansView(),
      ),
      GoRoute(
        path: '/owner/products/new',
        builder: (BuildContext context, GoRouterState state) =>
            const ProductUploadView(),
      ),
      GoRoute(
        path: '/owner/orders/:id',
        builder: (BuildContext context, GoRouterState state) =>
            OwnerOrderDetailView(
              orderId: state.pathParameters['id'] ?? '',
              order: state.extra is OrderModel
                  ? state.extra! as OrderModel
                  : null,
            ),
      ),
      GoRoute(
        path: '/owner/products/:id/edit',
        builder: (BuildContext context, GoRouterState state) => ProductEditView(
          product: state.extra is ProductModel
              ? state.extra! as ProductModel
              : null,
          productId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/owner/products/bulk-upload',
        builder: (BuildContext context, GoRouterState state) =>
            const BulkUploadView(),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final String loc = state.matchedLocation;
      const Set<String> publicPaths = <String>{
        '/',
        '/welcome',
        '/login',
        '/register',
        '/forgot-password',
        '/profile',
        '/terms',
        '/privacy',
      };
      const Set<String> authEntryPaths = <String>{
        '/welcome',
        '/login',
        '/register',
        '/forgot-password',
      };
      const Set<String> onboardingPaths = <String>{
        '/select-role',
        '/onboarding/customer',
        '/onboarding/business',
      };
      final bool isPublic = publicPaths.contains(loc) || loc.startsWith('/s/');
      final bool isAuthEntry = authEntryPaths.contains(loc);
      final bool isOnboarding = onboardingPaths.contains(loc);

      // Build white-label (TENANT_SLUG fijo): la raíz es el catálogo del local.
      final TenantResolver resolver = ref.read(tenantResolverProvider);
      if (resolver.isWhiteLabel && loc == '/') {
        return '/s/${resolver.fixedSlug}';
      }

      final Session? session = ref.read(sessionProvider);
      if (session == null) return isPublic ? null : '/login';

      final AsyncValue<UserModel?> profileAsync = ref.read(
        currentProfileProvider,
      );
      // Sin datos todavía (cargando o error de red): no redirigir.
      if (profileAsync.isLoading || profileAsync.hasError) return null;
      final UserModel? profile = profileAsync.value;
      if (profile == null) return isOnboarding ? null : '/select-role';
      if (loc.startsWith('/admin') && !profile.isAdmin) return '/';
      if (profile.isOwner) {
        final bool inCustomerMode = ref.read(customerModeProvider);
        if (isAuthEntry || isOnboarding || (loc == '/' && !inCustomerMode)) {
          final String? returnTo = ref
              .read(returnToProvider.notifier)
              .consume();
          if (returnTo != null && returnTo != '/' && returnTo != '/profile') {
            return returnTo;
          }
          return '/owner';
        }
        return null;
      }
      // customer: allow '/onboarding/business' so an existing customer can
      // open their own store and upgrade their account to owner.
      if (loc == '/onboarding/business') return null;
      if (isAuthEntry || isOnboarding || loc.startsWith('/owner')) {
        final String? returnTo = ref.read(returnToProvider.notifier).consume();
        return returnTo ?? '/';
      }
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
  );
});
