import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final FutureProvider<List<TenantModel>> activeTenantsProvider =
    FutureProvider<List<TenantModel>>(
  (Ref ref) => ref.watch(tenantRepositoryProvider).listActive(),
);

class StoreDirectoryView extends ConsumerWidget {
  const StoreDirectoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TenantModel>> tenants =
        ref.watch(activeTenantsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              final UserModel? profile =
                  ref.read(currentProfileProvider).value;
              if (profile != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Sesión iniciada como ${profile.fullName}'),
                    action: SnackBarAction(
                      label: 'Salir',
                      onPressed: () => ref
                          .read(authControllerProvider.notifier)
                          .signOut(),
                    ),
                  ),
                );
              } else {
                context.go('/welcome');
              }
            },
          ),
        ],
      ),
      body: tenants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(AppStrings.genericError),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(activeTenantsProvider),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
        data: (List<TenantModel> list) {
          if (list.isEmpty) {
            return const Center(child: Text(AppStrings.noStoresYet));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final TenantModel tenant = list[index];
              return ListTile(
                title: Text(tenant.name),
                subtitle: tenant.description == null
                    ? null
                    : Text(tenant.description!),
                onTap: () => context.go('/s/${tenant.slug}'),
              );
            },
          );
        },
      ),
    );
  }
}
