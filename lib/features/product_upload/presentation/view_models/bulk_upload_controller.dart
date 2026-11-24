import 'dart:math';
import 'dart:typed_data';

import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/features/auth/presentation/view_models/auth_providers.dart';
import 'package:all_commerce/features/catalog/presentation/view_models/catalog_providers.dart';
import 'package:all_commerce/features/product_upload/data/models/ai_product_suggestion.dart';
import 'package:all_commerce/features/product_upload/data/models/bulk_product_draft.dart';
import 'package:all_commerce/features/product_upload/data/models/product_input.dart';
import 'package:all_commerce/features/product_upload/data/repositories/product_repository.dart';
import 'package:all_commerce/features/product_upload/data/services/ai_analyze_service.dart';
import 'package:all_commerce/features/product_upload/data/services/image_service.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maximum number of images allowed in one bulk upload session.
const int kBulkUploadLimit = 20;

/// Maximum concurrent AI analyses in a bulk upload session. Keeps throughput
/// ~2x faster than sequential while respecting Gemini free-tier RPM limits.
const int kBulkConcurrency = 2;

class BulkUploadState {
  const BulkUploadState({
    this.drafts = const <BulkProductDraft>[],
    this.analyzing = false,
    this.publishing = false,
    this.error,
  });

  final List<BulkProductDraft> drafts;
  final bool analyzing;
  final bool publishing;
  final String? error;

  BulkUploadState copyWith({
    List<BulkProductDraft>? drafts,
    bool? analyzing,
    bool? publishing,
    String? error,
  }) {
    return BulkUploadState(
      drafts: drafts ?? this.drafts,
      analyzing: analyzing ?? this.analyzing,
      publishing: publishing ?? this.publishing,
      error: error ?? this.error,
    );
  }

  int get analyzedCount => drafts.where((d) => d.analyzed).length;
  int get analyzingCount => drafts.where((d) => d.analyzing).length;
  int get validCount => drafts.where((d) => d.isValid).length;
  int get errorCount =>
      drafts.where((d) => d.analyzed && d.error != null).length;
  int get missingPriceCount =>
      drafts.where((d) => d.analyzed && d.error == null && !d.isValid).length;
  int get attentionCount => errorCount + missingPriceCount;
  int get publishableCount =>
      drafts.where((d) => d.isValid && d.analyzed && d.error == null).length;
  int get publishedCount =>
      drafts.where((d) => d.imageUrl != null && d.imageUrl!.isNotEmpty).length;
}

final NotifierProvider<BulkUploadController, BulkUploadState>
bulkUploadControllerProvider =
    NotifierProvider<BulkUploadController, BulkUploadState>(
      BulkUploadController.new,
    );

class BulkUploadController extends Notifier<BulkUploadState> {
  final ImageService _imageService = const ImageService();
  late final AiAnalyzeService _aiService;
  late final ProductRepository _productRepository;

  @override
  BulkUploadState build() {
    _aiService = AiAnalyzeService(ref.read(supabaseClientProvider));
    _productRepository = ProductRepository(ref.read(supabaseClientProvider));
    return const BulkUploadState();
  }

  String _makeId() {
    final Random random = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(1 << 20)}';
  }

  /// Pick images, compress them, and run AI analysis with bounded concurrency.
  /// When analysis finishes, drafts with errors or missing prices are moved to
  /// the top so the owner can fix them without scrolling.
  Future<void> pickAndAnalyze() async {
    final List<PickedImage> images = await _imageService.pickMultiple(
      limit: kBulkUploadLimit,
    );
    if (images.isEmpty) return;

    final List<BulkProductDraft> drafts = <BulkProductDraft>[
      for (final PickedImage img in images)
        BulkProductDraft(
          id: _makeId(),
          imageBytes: img.bytes,
          fileName: img.name,
        ),
    ];
    state = state.copyWith(drafts: drafts, analyzing: true, error: null);

    await _runWorkersForIds(<String>[for (final d in drafts) d.id]);
    state = state.copyWith(
      drafts: _prioritizeDrafts(state.drafts),
      analyzing: false,
    );
  }

  Future<void> _runWorkersForIds(List<String> ids) async {
    if (ids.isEmpty) return;
    int nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        final int current = nextIndex++;
        if (current >= ids.length) break;
        await _analyzeById(ids[current]);
      }
    }

    final int workers = min(kBulkConcurrency, ids.length);
    await Future.wait(<Future<void>>[
      for (int w = 0; w < workers; w++) worker(),
    ]);
  }

  /// Sorts drafts so items needing attention appear first:
  /// 0 = error, 1 = missing title/price, 2 = ready to publish.
  static List<BulkProductDraft> _prioritizeDrafts(
    List<BulkProductDraft> source,
  ) {
    int rank(BulkProductDraft d) {
      if (d.error != null) return 0;
      if (!d.isValid) return 1;
      return 2;
    }

    final List<MapEntry<int, BulkProductDraft>> indexed = source
        .asMap()
        .entries
        .toList();
    indexed.sort((a, b) {
      final int r = rank(a.value).compareTo(rank(b.value));
      return r != 0 ? r : a.key.compareTo(b.key);
    });
    return <BulkProductDraft>[for (final entry in indexed) entry.value];
  }

  int _indexOfId(String id) =>
      state.drafts.indexWhere((BulkProductDraft d) => d.id == id);

  Future<void> _analyzeById(String draftId) async {
    final int initialIndex = _indexOfId(draftId);
    if (initialIndex < 0) return;
    final BulkProductDraft initial = state.drafts[initialIndex];
    _setDraftById(draftId, initial.copyWith(analyzing: true, clearError: true));

    Uint8List? compressed;
    try {
      compressed = await _imageService.compress(initial.imageBytes);
    } catch (_) {
      final int idx = _indexOfId(draftId);
      if (idx < 0) return;
      _setDraftById(
        draftId,
        state.drafts[idx].copyWith(
          analyzing: false,
          analyzed: true,
          error: 'No se pudo procesar el archivo de imagen',
        ),
      );
      return;
    }

    const int maxAttempts = 3;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final AiProductSuggestion suggestion = await _aiService.analyze(
          compressed,
        );
        final int idx = _indexOfId(draftId);
        if (idx < 0) return;
        _setDraftById(
          draftId,
          state.drafts[idx].copyWith(
            title: suggestion.title,
            description: suggestion.description,
            category: suggestion.category,
            tags: suggestion.tags,
            price: suggestion.suggestedPriceArs,
            sku: suggestion.sku,
            analyzed: true,
            analyzing: false,
            clearError: true,
          ),
        );
        return;
      } on AiAnalyzeException catch (e) {
        final bool canRetry = e.isRetryable && attempt < maxAttempts - 1;
        if (canRetry) {
          final Duration wait = e.code == 'AI_RATE_LIMITED'
              ? Duration(seconds: 4 * (attempt + 1))
              : Duration(milliseconds: 1200 * (attempt + 1));
          await Future<void>.delayed(wait);
          continue;
        }
        final int idx = _indexOfId(draftId);
        if (idx < 0) return;
        _setDraftById(
          draftId,
          state.drafts[idx].copyWith(
            analyzing: false,
            analyzed: true,
            error: e.message,
          ),
        );
        return;
      } catch (_) {
        if (attempt < maxAttempts - 1) {
          await Future<void>.delayed(
            Duration(milliseconds: 1200 * (attempt + 1)),
          );
          continue;
        }
        final int idx = _indexOfId(draftId);
        if (idx < 0) return;
        _setDraftById(
          draftId,
          state.drafts[idx].copyWith(
            analyzing: false,
            analyzed: true,
            error: 'No se pudo analizar la foto',
          ),
        );
        return;
      }
    }
  }

  void updateDraft(int index, BulkProductDraft draft) {
    if (index < 0 || index >= state.drafts.length) return;
    final List<BulkProductDraft> updated = <BulkProductDraft>[...state.drafts];
    updated[index] = draft;
    state = state.copyWith(drafts: updated);
  }

  void removeDraft(int index) {
    if (index < 0 || index >= state.drafts.length) return;
    final List<BulkProductDraft> updated = <BulkProductDraft>[...state.drafts];
    updated.removeAt(index);
    state = state.copyWith(drafts: updated);
  }

  Future<void> retryAnalysis(int index) async {
    if (index < 0 || index >= state.drafts.length) return;
    await _analyzeById(state.drafts[index].id);
  }

  /// Retries all drafts that currently have an error.
  Future<void> retryAllFailed() async {
    final List<String> failedIds = <String>[
      for (final BulkProductDraft d in state.drafts)
        if (d.error != null) d.id,
    ];
    if (failedIds.isEmpty) return;
    state = state.copyWith(analyzing: true, error: null);
    await _runWorkersForIds(failedIds);
    state = state.copyWith(
      drafts: _prioritizeDrafts(state.drafts),
      analyzing: false,
    );
  }

  /// Dismiss the AI error on a draft so the owner can type title/price
  /// manually and still publish the photo with the rest of the batch.
  void fillManually(int index) {
    if (index < 0 || index >= state.drafts.length) return;
    final BulkProductDraft draft = state.drafts[index];
    _setDraft(
      index,
      draft.copyWith(analyzing: false, analyzed: true, clearError: true),
    );
  }

  /// Publish all valid drafts. Returns the number of products created.
  Future<int> publishAll() async {
    final String? tenantId = ref.read(currentProfileProvider).value?.tenantId;
    if (tenantId == null) {
      state = state.copyWith(error: 'No se encontró el local');
      return 0;
    }

    final List<BulkProductDraft> toPublish = state.drafts
        .where(
          (BulkProductDraft d) => d.isValid && d.analyzed && d.error == null,
        )
        .toList();
    if (toPublish.isEmpty) {
      state = state.copyWith(error: 'No hay productos listos para publicar');
      return 0;
    }

    state = state.copyWith(publishing: true, error: null);
    int published = 0;
    for (int i = 0; i < state.drafts.length; i++) {
      final BulkProductDraft draft = state.drafts[i];
      if (!draft.isValid || draft.error != null) continue;

      _setDraft(i, draft.copyWith(publishing: true));
      try {
        final double actualPrice = draft.price ?? 0;
        final double? compareAt =
            draft.compareAtPrice != null && draft.compareAtPrice! > actualPrice
            ? draft.compareAtPrice
            : null;
        final bool hasWholesale =
            draft.wholesalePrice != null &&
            draft.wholesalePrice! > 0 &&
            draft.wholesaleMinQty != null &&
            draft.wholesaleMinQty! >= 2;
        final ProductInput input = ProductInput(
          title: draft.title.trim(),
          description: draft.description?.trim(),
          category: draft.category,
          tags: draft.tags,
          price: actualPrice,
          compareAtPrice: compareAt,
          wholesalePrice: hasWholesale ? draft.wholesalePrice : null,
          wholesaleMinQty: hasWholesale
              ? draft.wholesaleMinQty?.toDouble()
              : null,
          sku: draft.sku?.trim(),
          variants: draft.variants,
          stock: draft.stock.toDouble(),
          trackStock: draft.stock > 0,
        );
        final product = await _productRepository.create(input, tenantId);
        final Uint8List compressed = await _imageService.compress(
          draft.imageBytes,
        );
        final String url = await _productRepository.uploadImage(
          tenantId: tenantId,
          productId: product.id,
          jpegBytes: compressed,
        );
        await _productRepository.setImageUrl(product.id, url);
        _setDraft(i, draft.copyWith(publishing: false, imageUrl: url));
        published++;
      } catch (e) {
        _setDraft(
          i,
          draft.copyWith(publishing: false, error: 'No se pudo publicar'),
        );
      }
    }

    state = state.copyWith(publishing: false);
    // Invalidate authoritative lists.
    ref.invalidate(ownerProductsProvider(tenantId));
    ref.invalidate(catalogProductsProvider(tenantId));
    return published;
  }

  void clear() => state = const BulkUploadState();

  void _setDraft(int index, BulkProductDraft draft) {
    if (index < 0 || index >= state.drafts.length) return;
    final List<BulkProductDraft> updated = <BulkProductDraft>[...state.drafts];
    updated[index] = draft;
    state = state.copyWith(drafts: updated);
  }

  void _setDraftById(String id, BulkProductDraft draft) {
    final int index = _indexOfId(id);
    if (index < 0) return;
    _setDraft(index, draft);
  }
}
