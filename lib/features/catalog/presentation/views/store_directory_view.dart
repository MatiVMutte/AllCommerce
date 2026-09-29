import 'package:all_commerce/core/constants/app_strings.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/features/auth/data/models/user_model.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class StoreDirectoryView extends ConsumerWidget {
  const StoreDirectoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TenantModel>> tenants =
        ref.watch(activeTenantsProvider);
    final String search = ref.watch(storeSearchProvider);
    final UserModel? profile = ref.watch(currentProfileProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: <Widget>[
          if (profile != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.person_outline),
              onSelected: (String value) {
                if (value == 'signOut') {
                  ref.read(authControllerProvider.notifier).signOut();
                } else if (value == 'myOrders') {
                  context.push('/my-orders');
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(profile.fullName),
                ),
                const PopupMenuItem<String>(
                  value: 'myOrders',
                  child: Text('Mis pedidos'),
                ),
                const PopupMenuItem<String>(
                  value: 'signOut',
                  child: Text(AppStrings.signOut),
                ),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push('/welcome'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: AppStrings.searchStores,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (String value) => ref
                      .read(storeSearchProvider.notifier)
                      .setQuery(value),
                ),
              ),
              Expanded(
                child: tenants.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace stack) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(AppStrings.genericError),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              ref.invalidate(activeTenantsProvider),
                          child: const Text(AppStrings.retry),
                        ),
                      ],
                    ),
                  ),
                  data: (List<TenantModel> list) {
                    if (list.isEmpty) {
                      return const Center(
                        child: Text(AppStrings.noStoresYet),
                      );
                    }
                    final List<TenantModel> filtered =
                        filterTenants(list, search);
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(AppStrings.noStoresFound),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _StoreCard(tenant: filtered[index]);
                      },
                    );
                  },
                ),
              ),
            ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: tenant.primaryColorValue,
          foregroundColor: Colors.white,
          child: tenant.logoUrl == null
              ? Text(tenant.name.characters.first.toUpperCase())
              : ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: tenant.logoUrl!,
                    fit: BoxFit.cover,
                    width: 40,
                    height: 40,
                    errorWidget: (BuildContext context, String url, _) =>
                        Text(tenant.name.characters.first.toUpperCase()),
                  ),
                ),
        ),
        title: Text(tenant.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (tenant.description != null)
              Text(tenant.description!, maxLines: 1),
            if (tenant.address != null)
              Row(
                children: <Widget>[
                  const Icon(Icons.place_outlined, size: 14),
                  const SizedBox(width: 2),
                  Expanded(child: Text(tenant.address!, maxLines: 1)),
                ],
              ),
          ],
        ),
        onTap: () => context.push('/s/${tenant.slug}'),
      ),
    );
  }
}
