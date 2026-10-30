import 'dart:typed_data';

import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/core/utils/auth_error_mapper.dart';
import 'package:all_commerce/features/billing/data/repositories/ai_usage_repository.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/features/product_upload/data/models/ai_product_suggestion.dart';
import 'package:all_commerce/features/product_upload/data/models/product_input.dart';
import 'package:all_commerce/features/product_upload/data/repositories/product_repository.dart';
import 'package:all_commerce/features/product_upload/data/services/ai_analyze_service.dart';
import 'package:all_commerce/features/product_upload/data/services/image_service.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<ImageService> imageServiceProvider = Provider<ImageService>(
  (_) => const ImageService(),
);

final Provider<AiAnalyzeService> aiAnalyzeServiceProvider =
    Provider<AiAnalyzeService>(
      (Ref ref) => AiAnalyzeService(ref.watch(supabaseClientProvider)),
    );

final Provider<ProductRepository> productRepositoryProvider =
    Provider<ProductRepository>(
      (Ref ref) => ProductRepository(ref.watch(supabaseClientProvider)),
    );

class ProductUploadState {
  const ProductUploadState({
    this.imageBytes,
    this.extraImageBytes = const <Uint8List>[],
    this.keptImageUrls = const <String>[],
    this.analyzing = false,
    this.saving = false,
    this.suggestion,
    this.infoMessage,
    this.error,
    this.blockedCode,
  });

  /// Newly picked main photo (replaces the cover when set).
  final Uint8List? imageBytes;

  /// Newly picked additional photos, appended after the cover.
  final List<Uint8List> extraImageBytes;

  /// Existing gallery URLs kept when editing.
  final List<String> keptImageUrls;

  final bool analyzing;
  final bool saving;
  final AiProductSuggestion? suggestion;

  /// Non-blocking message (e.g. AI unavailable, image upload failed).
  final String? infoMessage;
  final Object? error;

  /// 'PLAN_EXPIRED' | 'PRODUCT_LIMIT_REACHED' when blocked by plan rules.
  final String? blockedCode;

  /// Total photos currently selected (new + kept), cap for the picker.
  int get photoCount =>
      keptImageUrls.length +
      (imageBytes == null ? 0 : 1) +
      extraImageBytes.length;

  static const int maxPhotos = 4;

  ProductUploadState copyWith({
    Uint8List? Function()? imageBytes,
    List<Uint8List>? extraImageBytes,
    List<String>? keptImageUrls,
    bool? analyzing,
    bool? saving,
    AiProductSuggestion? Function()? suggestion,
    String? Function()? infoMessage,
    Object? Function()? error,
    String? Function()? blockedCode,
  }) {
    return ProductUploadState(
      imageBytes: imageBytes != null ? imageBytes() : this.imageBytes,
      extraImageBytes: extraImageBytes ?? this.extraImageBytes,
      keptImageUrls: keptImageUrls ?? this.keptImageUrls,
      analyzing: analyzing ?? this.analyzing,
      saving: saving ?? this.saving,
      suggestion: suggestion != null ? suggestion() : this.suggestion,
      infoMessage: infoMessage != null ? infoMessage() : this.infoMessage,
      error: error != null ? error() : this.error,
      blockedCode: blockedCode != null ? blockedCode() : this.blockedCode,
    );
  }
}

class ProductUploadController extends Notifier<ProductUploadState> {
  @override
  ProductUploadState build() => const ProductUploadState();

  ImageService get _images => ref.read(imageServiceProvider);
  AiAnalyzeService get _ai => ref.read(aiAnalyzeServiceProvider);
  ProductRepository get _products => ref.read(productRepositoryProvider);

  Future<void> pickAndAnalyze(ImageSource source) async {
    final PickedImage? picked = await _images.pick(source);
    if (picked == null) return;
    final Uint8List bytes = await _images.compress(picked.bytes);
    state = state.copyWith(
      imageBytes: () => bytes,
      analyzing: true,
      suggestion: () => null,
      infoMessage: () => null,
      error: () => null,
    );
    try {
      final AiProductSuggestion suggestion = await _ai.analyze(bytes);
      state = state.copyWith(analyzing: false, suggestion: () => suggestion);
    } on AiAnalyzeException catch (e) {
      if (e.code == 'PLAN_EXPIRED') {
        state = state.copyWith(analyzing: false, blockedCode: () => e.code);
        return;
      }
      state = state.copyWith(
        analyzing: false,
        infoMessage: () => AuthErrorMapper.toMessage(e),
        error: () => e,
      );
    } catch (e) {
      state = state.copyWith(
        analyzing: false,
        infoMessage: () =>
            'La IA no pudo analizar la foto, completá los datos a mano',
        error: () => e,
      );
    } finally {
      ref.invalidate(aiUsageProvider);
    }
  }

  /// Picks an extra photo appended to the gallery (no AI analysis).
  Future<void> pickExtra(ImageSource source) async {
    if (state.photoCount >= ProductUploadState.maxPhotos) return;
    final PickedImage? picked = await _images.pick(source);
    if (picked == null) return;
    final Uint8List bytes = await _images.compress(picked.bytes);
    state = state.copyWith(
      extraImageBytes: <Uint8List>[...state.extraImageBytes, bytes],
    );
  }

  void removeExtra(int index) {
    final List<Uint8List> next = List<Uint8List>.of(state.extraImageBytes)
      ..removeAt(index);
    state = state.copyWith(extraImageBytes: next);
  }

  void removeKept(String url) {
    state = state.copyWith(
      keptImageUrls: state.keptImageUrls.where((String u) => u != url).toList(),
    );
  }

  /// Seeds the kept gallery when editing a product that already has photos.
  void initGallery(List<String> urls) {
    state = state.copyWith(keptImageUrls: urls);
  }

  /// Uploads main + extra photos and persists the ordered gallery.
  /// Order: new cover first, kept URLs, then new extras.
  Future<void> _persistGallery(String tenantId, String productId) async {
    final List<String> urls = <String>[];
    try {
      final Uint8List? main = state.imageBytes;
      if (main != null) {
        urls.add(
          await _products.uploadImage(
            tenantId: tenantId,
            productId: productId,
            jpegBytes: main,
          ),
        );
      }
      urls.addAll(state.keptImageUrls);
      for (final Uint8List extra in state.extraImageBytes) {
        urls.add(
          await _products.uploadImage(
            tenantId: tenantId,
            productId: productId,
            jpegBytes: extra,
          ),
        );
      }
      await _products.setGallery(productId, urls);
    } catch (_) {
      state = state.copyWith(
        infoMessage: () =>
            'El producto se guardó pero alguna foto no se pudo subir',
      );
    }
  }

  /// Creates the product first (DB trigger enforces plan limits), then
  /// uploads the images and links them. A failed upload leaves the product
  /// created without photos.
  Future<ProductModel?> save(ProductInput input, String tenantId) async {
    state = state.copyWith(saving: true, error: () => null);
    final ProductModel product;
    try {
      product = await _products.create(input, tenantId);
    } on PostgrestException catch (e) {
      final String? blocked = _blockedCodeFrom(e.message);
      state = state.copyWith(
        saving: false,
        error: () => e,
        blockedCode: blocked != null ? () => blocked : null,
      );
      return null;
    } catch (e) {
      state = state.copyWith(saving: false, error: () => e);
      return null;
    }
    if (state.imageBytes != null || state.extraImageBytes.isNotEmpty) {
      await _persistGallery(tenantId, product.id);
    }
    ref.invalidate(catalogProductsProvider(tenantId));
    ref.invalidate(ownerProductsProvider(tenantId));
    state = state.copyWith(saving: false);
    return product;
  }

  /// Updates an existing product, uploading new images if any were picked
  /// and persisting gallery removals.
  Future<ProductModel?> update(
    ProductModel existing,
    ProductInput input,
  ) async {
    state = state.copyWith(saving: true, error: () => null);
    final ProductModel product;
    try {
      product = await _products.update(existing.id, existing.tenantId, input);
    } on PostgrestException catch (e) {
      final String? blocked = _blockedCodeFrom(e.message);
      state = state.copyWith(
        saving: false,
        error: () => e,
        blockedCode: blocked != null ? () => blocked : null,
      );
      return null;
    } catch (e) {
      state = state.copyWith(saving: false, error: () => e);
      return null;
    }
    final bool galleryChanged =
        state.imageBytes != null ||
        state.extraImageBytes.isNotEmpty ||
        state.keptImageUrls.length != existing.gallery.length;
    if (galleryChanged) {
      await _persistGallery(existing.tenantId, existing.id);
    }
    ref.invalidate(catalogProductsProvider(existing.tenantId));
    ref.invalidate(ownerProductsProvider(existing.tenantId));
    state = state.copyWith(saving: false);
    return product;
  }

  String? _blockedCodeFrom(String message) {
    if (message.contains('PRODUCT_LIMIT_REACHED')) {
      return 'PRODUCT_LIMIT_REACHED';
    }
    if (message.contains('PLAN_EXPIRED')) return 'PLAN_EXPIRED';
    return null;
  }

  void reset() => state = const ProductUploadState();
}

final productUploadControllerProvider =
    NotifierProvider.autoDispose<ProductUploadController, ProductUploadState>(
      ProductUploadController.new,
    );
