import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_repository.dart';
import 'package:all_commerce/core/tenant/tenant_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<TenantResolver> tenantResolverProvider =
    Provider<TenantResolver>((_) => const TenantResolver());

/// Store chosen by the customer in the directory.
class SelectedTenantSlugNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? slug) => state = slug;
}

final NotifierProvider<SelectedTenantSlugNotifier, String?>
    selectedTenantSlugProvider =
    NotifierProvider<SelectedTenantSlugNotifier, String?>(
  SelectedTenantSlugNotifier.new,
);

final Provider<TenantRepository> tenantRepositoryProvider =
    Provider<TenantRepository>(
  (Ref ref) => TenantRepository(ref.watch(supabaseClientProvider)),
);

final tenantBySlugProvider = FutureProvider.family<TenantModel?, String>(
  (Ref ref, String slug) =>
      ref.watch(tenantRepositoryProvider).getBySlug(slug),
);

final tenantByIdProvider = FutureProvider.family<TenantModel?, String>(
  (Ref ref, String id) => ref.watch(tenantRepositoryProvider).getById(id),
);

final activeTenantsProvider =
    FutureProvider.autoDispose.family<List<TenantModel>, String?>(
  (Ref ref, String? zone) =>
      ref.watch(tenantRepositoryProvider).listActiveByZone(zone),
);

final publicZonesProvider = FutureProvider.autoDispose<List<String>>(
  (Ref ref) => ref.watch(tenantRepositoryProvider).listZones(),
);
