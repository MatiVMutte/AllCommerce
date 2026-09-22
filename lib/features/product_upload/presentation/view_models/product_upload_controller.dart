import 'dart:typed_data';

import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/core/utils/auth_error_mapper.dart';
import 'package:all_commerce/features/catalog/data/models/product_model.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/features/product_upload/data/models/ai_product_suggestion.dart';
import 'package:all_commerce/features/product_upload/data/models/product_input.dart';
import 'package:all_commerce/features/product_upload/data/repositories/product_repository.dart';
import 'package:all_commerce/features/product_upload/data/services/ai_analyze_service.dart';
import 'package:all_commerce/features/product_upload/data/services/image_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Provider<ImageService> imageServiceProvider =
    Provider<ImageService>((_) => ImageService());

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
    this.analyzing = false,
    this.saving = false,
    this.suggestion,
    this.infoMessage,
    this.error,
    this.blockedCode,
  });

  final Uint8List? imageBytes;
  final bool analyzing;
  final bool saving;
  final AiProductSuggestion? suggestion;

  /// Non-blocking message (e.g. AI unavailable, image upload failed).
  final String? infoMessage;
  final Object? error;

  /// 'PLAN_EXPIRED' | 'PRODUCT_LIMIT_REACHED' when blocked by plan rules.
  final String? blockedCode;

  ProductUploadState copyWith({
    Uint8List? Function()? imageBytes,
    bool? analyzing,
    bool? saving,
    AiProductSuggestion? Function()? suggestion,
    String? Function()? infoMessage,
    Object? Function()? error,
    String? Function()? blockedCode,
  }) {
    return ProductUploadState(
      imageBytes: imageBytes != null ? imageBytes() : this.imageBytes,
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
        state = state.copyWith(
          analyzing: false,
          blockedCode: () => e.code,
        );
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
    }
  }

  /// Creates the product first (DB trigger enforces plan limits), then
  /// uploads the image and links it. A failed upload leaves the product
  /// created without a photo.
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
    final Uint8List? image = state.imageBytes;
    if (image != null) {
      try {
        final String url = await _products.uploadImage(
          tenantId: tenantId,
          productId: product.id,
          jpegBytes: image,
        );
        await _products.setImageUrl(product.id, url);
      } catch (_) {
        state = state.copyWith(
          infoMessage: () =>
              'El producto se guardó pero la foto no se pudo subir',
        );
      }
    }
    ref.invalidate(catalogProductsProvider(tenantId));
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
