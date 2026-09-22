import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/router/router_refresh.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/tenant/tenant_strategy.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/auth/presentation/views/customer_profile_view.dart';
import 'package:all_commerce/features/auth/presentation/views/forgot_password_view.dart';
import 'package:all_commerce/features/auth/presentation/views/login_view.dart';
import 'package:all_commerce/features/auth/presentation/views/register_view.dart';
import 'package:all_commerce/features/auth/presentation/views/role_select_view.dart';
import 'package:all_commerce/features/auth/presentation/views/welcome_view.dart';
import 'package:all_commerce/features/catalog/presentation/views/catalog_view.dart';
import 'package:all_commerce/features/catalog/presentation/views/product_detail_view.dart';
import 'package:all_commerce/features/product_upload/presentation/views/product_upload_view.dart';
import 'package:all_commerce/features/catalog/presentation/views/store_directory_view.dart';
import 'package:all_commerce/features/store/presentation/views/business_onboarding_view.dart';
import 'package:all_commerce/features/store/presentation/views/owner_home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>(
  (Ref ref) {
    final RouterRefreshNotifier refreshNotifier =
        RouterRefreshNotifier(ref.read(authRepositoryProvider));
    ref.onDispose(refreshNotifier.dispose);
    ref.listen(currentProfileProvider, (_, _) {
      refreshNotifier.refresh();
    });
    return GoRouter(
      refreshListenable: refreshNotifier,
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
        GoRoute(
          path: '/owner',
          builder: (BuildContext context, GoRouterState state) =>
              const OwnerHomeView(),
        ),
        GoRoute(
          path: '/owner/products/new',
          builder: (BuildContext context, GoRouterState state) =>
              const ProductUploadView(),
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
        final bool isPublic =
            publicPaths.contains(loc) || loc.startsWith('/s/');
        final bool isAuthEntry = authEntryPaths.contains(loc);
        final bool isOnboarding = onboardingPaths.contains(loc);

        // Build white-label (TENANT_SLUG fijo): la raíz es el catálogo del local.
        final TenantResolver resolver = ref.read(tenantResolverProvider);
        if (resolver.isWhiteLabel && loc == '/') {
          return '/s/${resolver.fixedSlug}';
        }

        final Session? session = ref.read(sessionProvider);
        if (session == null) return isPublic ? null : '/login';

        final AsyncValue<UserModel?> profileAsync =
            ref.read(currentProfileProvider);
        // Sin datos todavía (cargando o error de red): no redirigir.
        if (profileAsync.isLoading || profileAsync.hasError) return null;
        final UserModel? profile = profileAsync.value;
        if (profile == null) return isOnboarding ? null : '/select-role';
        if (profile.isOwner) {
          return (isAuthEntry || isOnboarding || loc == '/') ? '/owner' : null;
        }
        // customer
        return (isAuthEntry || isOnboarding || loc.startsWith('/owner'))
            ? '/'
            : null;
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
  },
);
