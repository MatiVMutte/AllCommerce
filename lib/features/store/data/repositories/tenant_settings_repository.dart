import 'dart:typed_data';

import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<TenantSettingsRepository> tenantSettingsRepositoryProvider =
    Provider<TenantSettingsRepository>(
      (Ref ref) => TenantSettingsRepository(ref.watch(supabaseClientProvider)),
    );

class TenantSettingsRepository {
  const TenantSettingsRepository(this._client);

  final SupabaseClient _client;

  Future<TenantModel> update(
    String tenantId, {
    required String name,
    String? description,
    String? address,
    double? lat,
    double? lng,
    required String whatsapp,
    required String primaryColor,
    String? transferAlias,
    String? mercadoPagoLink,
    bool acceptsCard = false,
    bool acceptsCash = true,
    bool isOpen = true,
    String? openingHours,
    bool isPublic = true,
    double cashDiscountPct = 0,
    double transferDiscountPct = 0,
    double mpDiscountPct = 0,
    double bulkDiscountPct = 0,
    double bulkDiscountMin = 0,
  }) async {
    final Map<String, dynamic> row = await _client
        .from('tenants')
        .update(<String, dynamic>{
          'name': name,
          'description': description,
          'address': address,
          'lat': lat,
          'lng': lng,
          'whatsapp': whatsapp,
          'primary_color': primaryColor,
          'transfer_alias': transferAlias,
          'mercado_pago_link': mercadoPagoLink,
          'accepts_card': acceptsCard,
          'accepts_cash': acceptsCash,
          'is_open': isOpen,
          'opening_hours': openingHours,
          'is_public': isPublic,
          'cash_discount_pct': cashDiscountPct,
          'transfer_discount_pct': transferDiscountPct,
          'mp_discount_pct': mpDiscountPct,
          'bulk_discount_pct': bulkDiscountPct,
          'bulk_discount_min': bulkDiscountMin,
        })
        .eq('id', tenantId)
        .select()
        .single();
    return TenantModel.fromJson(row);
  }

  /// Instant-save for the payment capability switches (cash / card).
  Future<void> setPaymentFlags(
    String tenantId, {
    required bool acceptsCash,
    required bool acceptsCard,
  }) async {
    await _client
        .from('tenants')
        .update(<String, dynamic>{
          'accepts_cash': acceptsCash,
          'accepts_card': acceptsCard,
        })
        .eq('id', tenantId);
  }

  Future<void> setOpen(String tenantId, bool isOpen) async {
    await _client
        .from('tenants')
        .update(<String, dynamic>{'is_open': isOpen})
        .eq('id', tenantId);
  }

  /// Uploads a JPEG logo (max 512px, compressed by ImageService).
  /// Returns the public URL with a cache-busting `?v=` param.
  Future<String> uploadLogo({
    required String tenantId,
    required Uint8List bytes,
  }) async {
    final String path = '$tenantId/logo.jpg';
    await _client.storage
        .from('tenant-logos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final String url = _client.storage.from('tenant-logos').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> setLogoUrl(String tenantId, String url) async {
    await _client
        .from('tenants')
        .update(<String, dynamic>{'logo_url': url})
        .eq('id', tenantId);
  }

  /// Uploads a JPEG cover banner (compressed by ImageService).
  /// Stored in the same `tenant-logos` bucket — its policies already
  /// scope writes to the tenant's own folder.
  /// Returns the public URL with a cache-busting `?v=` param.
  Future<String> uploadCover({
    required String tenantId,
    required Uint8List bytes,
  }) async {
    final String path = '$tenantId/cover.jpg';
    await _client.storage
        .from('tenant-logos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final String url = _client.storage.from('tenant-logos').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> setCoverUrl(String tenantId, String url) async {
    await _client
        .from('tenants')
        .update(<String, dynamic>{'cover_url': url})
        .eq('id', tenantId);
  }
}
