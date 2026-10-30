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
    final keepAlive = ref.keepAlive();
    try {
      final PickedImage? picked = await ref
          .read(imageServiceProvider)
          .pick(ImageSource.gallery);
      if (picked == null) return;
      final Uint8List jpeg = await ref
          .read(imageServiceProvider)
          .compressLogo(picked.bytes);
      state = TenantSettingsState(pendingLogo: jpeg);
    } finally {
      keepAlive.close();
    }
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
    bool acceptsCard = false,
    bool acceptsCash = true,
    bool isOpen = true,
    String? openingHours,
  }) async {
    final keepAlive = ref.keepAlive();
    final TenantSettingsRepository repo = ref.read(
      tenantSettingsRepositoryProvider,
    );
    state = TenantSettingsState(saving: true, pendingLogo: state.pendingLogo);
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
        acceptsCard: acceptsCard,
        acceptsCash: acceptsCash,
        isOpen: isOpen,
        openingHours: openingHours,
      );
      final Uint8List? logo = state.pendingLogo;
      if (logo != null) {
        final String url = await repo.uploadLogo(
          tenantId: current.id,
          bytes: logo,
        );
        await repo.setLogoUrl(current.id, url);
      }
      state = const TenantSettingsState();
      ref.invalidate(tenantByIdProvider(current.id));
      ref.invalidate(tenantBySlugProvider(current.slug));
      return updated;
    } catch (e) {
      state = TenantSettingsState(pendingLogo: state.pendingLogo, error: e);
      return null;
    } finally {
      keepAlive.close();
    }
  }

  /// Persists the payment capability switches immediately — they behave
  /// like quick toggles, not form fields.
  Future<bool> setPaymentFlags(
    TenantModel current, {
    required bool acceptsCash,
    required bool acceptsCard,
  }) async {
    final keepAlive = ref.keepAlive();
    try {
      final TenantSettingsRepository repo = ref.read(
        tenantSettingsRepositoryProvider,
      );
      await repo.setPaymentFlags(
        current.id,
        acceptsCash: acceptsCash,
        acceptsCard: acceptsCard,
      );
      ref.invalidate(tenantByIdProvider(current.id));
      ref.invalidate(tenantBySlugProvider(current.slug));
      return true;
    } catch (e) {
      state = TenantSettingsState(pendingLogo: state.pendingLogo, error: e);
      return false;
    } finally {
      keepAlive.close();
    }
  }

  Future<bool> toggleOpen(TenantModel current) async {
    // The provider is autoDispose: keep it alive across the async gap and
    // the tenantByIdProvider invalidation, which can otherwise dispose this
    // controller mid-flight (UnmountedRefException).
    final keepAlive = ref.keepAlive();
    try {
      final TenantSettingsRepository repo = ref.read(
        tenantSettingsRepositoryProvider,
      );
      await repo.setOpen(current.id, !current.isOpen);
      ref.invalidate(tenantByIdProvider(current.id));
      ref.invalidate(tenantBySlugProvider(current.slug));
      return true;
    } catch (e) {
      state = TenantSettingsState(pendingLogo: state.pendingLogo, error: e);
      return false;
    } finally {
      keepAlive.close();
    }
  }
}

final tenantSettingsControllerProvider =
    NotifierProvider.autoDispose<TenantSettingsController, TenantSettingsState>(
      TenantSettingsController.new,
    );
