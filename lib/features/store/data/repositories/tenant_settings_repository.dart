import 'dart:typed_data';

import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<TenantSettingsRepository> tenantSettingsRepositoryProvider =
    Provider<TenantSettingsRepository>(
  (Ref ref) =>
      TenantSettingsRepository(ref.watch(supabaseClientProvider)),
);

class TenantSettingsRepository {
  const TenantSettingsRepository(this._client);

  final SupabaseClient _client;

  Future<TenantModel> update(
    String tenantId, {
    required String name,
    String? description,
    String? address,
    required String whatsapp,
    required String primaryColor,
  }) async {
    final Map<String, dynamic> row = await _client
        .from('tenants')
        .update(<String, dynamic>{
          'name': name,
          'description': description,
          'address': address,
          'whatsapp': whatsapp,
          'primary_color': primaryColor,
        })
        .eq('id', tenantId)
        .select()
        .single();
    return TenantModel.fromJson(row);
  }

  /// Uploads a JPEG logo (max 512px, compressed by ImageService).
  /// Returns the public URL with a cache-busting `?v=` param.
  Future<String> uploadLogo({
    required String tenantId,
    required Uint8List bytes,
  }) async {
    final String path = '$tenantId/logo.jpg';
    await _client.storage.from('tenant-logos').uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    final String url =
        _client.storage.from('tenant-logos').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> setLogoUrl(String tenantId, String url) async {
    await _client
        .from('tenants')
        .update(<String, dynamic>{'logo_url': url})
        .eq('id', tenantId);
  }
}
