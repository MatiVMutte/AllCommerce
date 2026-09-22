import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_repository.dart';
import 'package:all_commerce/core/tenant/tenant_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final Provider<TenantResolver> tenantResolverProvider =
    Provider<TenantResolver>((_) => const TenantResolver());

/// Store chosen by the customer in the directory.
final StateProvider<String?> selectedTenantSlugProvider =
    StateProvider<String?>((_) => null);

final Provider<TenantRepository> tenantRepositoryProvider =
    Provider<TenantRepository>(
  (Ref ref) => TenantRepository(ref.watch(supabaseClientProvider)),
);

final tenantBySlugProvider = FutureProvider.family<TenantModel?, String>(
  (Ref ref, String slug) =>
      ref.watch(tenantRepositoryProvider).getBySlug(slug),
);
