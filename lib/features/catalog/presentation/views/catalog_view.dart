import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/core/theme/app_theme.dart';
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
          child: Scaffold(
            appBar: AppBar(title: Text(tenant.name)),
            body: Center(child: Text('Catálogo de ${tenant.name}')),
          ),
        );
      },
    );
  }
}
