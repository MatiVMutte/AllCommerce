import 'dart:typed_data';

import 'package:all_commerce/core/tenant/tenant_model.dart';
import 'package:all_commerce/core/tenant/tenant_resolver.dart';
import 'package:all_commerce/features/product_upload/data/services/image_service.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/product_upload_controller.dart';
import 'package:all_commerce/features/store/data/repositories/tenant_settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class TenantSettingsState {
  const TenantSettingsState({
    this.saving = false,
    this.pendingLogo,
    this.error,
  });

  final bool saving;

  /// Picked + compressed logo waiting to be uploaded on save.
  final Uint8List? pendingLogo;
  final Object? error;
}

class TenantSettingsController extends Notifier<TenantSettingsState> {
  @override
  TenantSettingsState build() => const TenantSettingsState();

  Future<void> pickLogo() async {
    final PickedImage? picked =
        await ref.read(imageServiceProvider).pick(ImageSource.gallery);
    if (picked == null) return;
    final Uint8List jpeg =
        await ref.read(imageServiceProvider).compressLogo(picked.bytes);
    state = TenantSettingsState(pendingLogo: jpeg);
  }

  /// Returns the updated tenant on success, null on failure.
  Future<TenantModel?> save(
    TenantModel current, {
    required String name,
    String? description,
    String? address,
    double? lat,
    double? lng,
    required String whatsapp,
    required String primaryColor,
    String? transferAlias,
    String? mercadoPagoLink,
    bool acceptsCash = true,
    bool isOpen = true,
    String? openingHours,
  }) async {
    final TenantSettingsRepository repo =
        ref.read(tenantSettingsRepositoryProvider);
    state = TenantSettingsState(
      saving: true,
      pendingLogo: state.pendingLogo,
    );
    try {
      final TenantModel updated = await repo.update(
        current.id,
        name: name,
        description: description,
        address: address,
        lat: lat,
        lng: lng,
        whatsapp: whatsapp,
        primaryColor: primaryColor,
        transferAlias: transferAlias,
        mercadoPagoLink: mercadoPagoLink,
        acceptsCash: acceptsCash,
        isOpen: isOpen,
        openingHours: openingHours,
      );
      final Uint8List? logo = state.pendingLogo;
      if (logo != null) {
        final String url =
            await repo.uploadLogo(tenantId: current.id, bytes: logo);
        await repo.setLogoUrl(current.id, url);
      }
      state = const TenantSettingsState();
      ref.invalidate(tenantByIdProvider(current.id));
      ref.invalidate(tenantBySlugProvider(current.slug));
      return updated;
    } catch (e) {
      state = TenantSettingsState(pendingLogo: state.pendingLogo, error: e);
      return null;
    }
  }

  Future<bool> toggleOpen(TenantModel current) async {
    final TenantSettingsRepository repo =
        ref.read(tenantSettingsRepositoryProvider);
    try {
      await repo.setOpen(current.id, !current.isOpen);
      ref.invalidate(tenantByIdProvider(current.id));
      ref.invalidate(tenantBySlugProvider(current.slug));
      return true;
    } catch (e) {
      state = TenantSettingsState(pendingLogo: state.pendingLogo, error: e);
      return false;
    }
  }
}

final tenantSettingsControllerProvider = NotifierProvider.autoDispose<
    TenantSettingsController, TenantSettingsState>(
  TenantSettingsController.new,
);
