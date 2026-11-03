import 'dart:typed_data';

import 'package:all_commerce/core/supabase/supabase_client_provider.dart';
import 'package:all_commerce/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:all_commerce/features/ai_chat/data/services/ai_chat_service.dart';
import 'package:all_commerce/features/billing/data/repositories/ai_usage_repository.dart';
import 'package:all_commerce/features/product_upload/data/models/product_input.dart';
import 'package:all_commerce/features/product_upload/presentation/view_models/product_upload_controller.dart';
import 'package:all_commerce/features/store/presentation/view_models/owner_products_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<AiChatService> aiChatServiceProvider = Provider<AiChatService>(
  (Ref ref) => AiChatService(ref.watch(supabaseClientProvider)),
);

class AiChatState {
  const AiChatState({
    this.messages = const <AiChatMessage>[],
    this.sending = false,
    this.quota,
  });

  final List<AiChatMessage> messages;
  final bool sending;

  /// Remaining monthly analyses after the last turn (null = still unknown).
  final AiUsage? quota;
}

/// Owner ↔ AI conversation. The edge function reads data and proposes
/// changes; confirming a proposal executes it through ProductRepository,
/// under the owner's own permissions.
class AiChatController extends Notifier<AiChatState> {
  @override
  AiChatState build() => const AiChatState();

  Future<void> send(String text, {Uint8List? imageBytes}) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty && imageBytes == null) return;
    if (state.sending) return;

    final List<AiChatMessage> history = state.messages;
    state = AiChatState(
      sending: true,
      quota: state.quota,
      messages: <AiChatMessage>[
        ...history,
        AiChatMessage(
          isUser: true,
          text: trimmed.isEmpty ? '(foto adjunta)' : trimmed,
          imageBytes: imageBytes,
        ),
      ],
    );

    try {
      // The history sent to the function ends at the message just added —
      // text turns only; the image rides the last user turn.
      final AiChatResponse res = await ref
          .read(aiChatServiceProvider)
          .send(history: state.messages, imageBytes: imageBytes);
      state = AiChatState(
        quota: res.quota ?? state.quota,
        messages: <AiChatMessage>[
          ...state.messages,
          AiChatMessage(
            isUser: false,
            text: res.reply,
            actions: res.actions
                .map(
                  (AiAction a) => AiAction(
                    type: a.type,
                    data: a.data,
                    imageBytes:
                        a.type == AiActionType.product ||
                            a.type == AiActionType.productImage
                        ? imageBytes
                        : null,
                  ),
                )
                .toList(),
          ),
        ],
      );
    } on AiChatException catch (e) {
      state = AiChatState(
        quota: state.quota,
        messages: <AiChatMessage>[
          ...state.messages,
          AiChatMessage(isUser: false, text: e.message, isError: true),
        ],
      );
    } catch (_) {
      state = AiChatState(
        quota: state.quota,
        messages: <AiChatMessage>[
          ...state.messages,
          AiChatMessage(
            isUser: false,
            text: 'No pude conectarme con la IA. Probá de nuevo.',
            isError: true,
          ),
        ],
      );
    }
  }

  /// Executes a confirmed proposal through the normal product repository —
  /// the owner's own permissions apply (RLS). Returns the snackbar text or
  /// throws.
  Future<String> confirm(
    AiChatMessage message,
    AiAction action,
    String tenantId,
  ) async {
    final repo = ref.read(productRepositoryProvider);
    final String done;
    switch (action.type) {
      case AiActionType.product:
        final input = ProductInput(
          title: action.data['title'] as String? ?? 'Producto',
          description: action.data['description'] as String?,
          category: action.data['category'] as String? ?? 'other',
          tags:
              (action.data['tags'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              const <String>[],
          price: (action.data['price'] as num?)?.toDouble() ?? 0,
          sku: action.data['sku'] as String?,
          unit: action.data['unit'] as String? ?? 'unidad',
          stock: (action.data['stock'] as num?)?.toDouble() ?? 0,
          trackStock: action.data['track_stock'] as bool? ?? false,
        );
        final product = await repo.create(input, tenantId);
        final Uint8List? img = action.imageBytes;
        if (img != null) {
          final String url = await repo.uploadImage(
            tenantId: tenantId,
            productId: product.id,
            jpegBytes: img,
          );
          await repo.setImageUrl(product.id, url);
        }
        done = 'Producto "${input.title}" publicado';
      case AiActionType.stockUpdate:
        await repo.setStock(
          action.data['product_id'] as String,
          tenantId,
          stock: (action.data['stock'] as num).toDouble(),
          trackStock: action.data['track_stock'] as bool? ?? true,
        );
        done = 'Stock de "${action.productTitle}" actualizado';
      case AiActionType.priceUpdate:
        await repo.setPrice(
          action.data['product_id'] as String,
          tenantId,
          price: (action.data['price'] as num).toDouble(),
        );
        done = 'Precio de "${action.productTitle}" actualizado';
      case AiActionType.productActive:
        final bool active = action.data['is_active'] as bool? ?? true;
        await repo.setActive(
          action.data['product_id'] as String,
          tenantId,
          active,
        );
        done = active
            ? '"${action.productTitle}" reactivado'
            : '"${action.productTitle}" pausado';
      case AiActionType.productFeatured:
        final bool featured = action.data['is_featured'] as bool? ?? true;
        await repo.setFeatured(
          action.data['product_id'] as String,
          tenantId,
          featured,
        );
        done = featured
            ? '"${action.productTitle}" destacado'
            : '"${action.productTitle}" ya no es destacado';
      case AiActionType.productDiscount:
        final double price = (action.data['price'] as num).toDouble();
        final double? compareAt = (action.data['compare_at_price'] as num?)
            ?.toDouble();
        await repo.setDiscount(
          action.data['product_id'] as String,
          tenantId,
          price: price,
          compareAtPrice: compareAt,
        );
        done = compareAt != null
            ? 'Oferta aplicada en "${action.productTitle}"'
            : 'Oferta quitada de "${action.productTitle}"';
      case AiActionType.bulkPriceChange:
        final double pct = (action.data['percent'] as num).toDouble();
        final String? category = action.data['category'] as String?;
        final int count = await repo.adjustPricesByPercent(
          tenantId,
          percent: pct,
          category: category,
        );
        final String sign = pct >= 0 ? '+$pct%' : '$pct%';
        done = 'Precios ajustados ($sign) en $count productos';
      case AiActionType.productImage:
        final Uint8List? img = action.imageBytes;
        if (img == null) {
          throw StateError('La propuesta no tiene imagen adjunta');
        }
        final String productId = action.data['product_id'] as String;
        final String url = await repo.uploadImage(
          tenantId: tenantId,
          productId: productId,
          jpegBytes: img,
        );
        await repo.setImageUrl(productId, url);
        done = 'Foto de "${action.productTitle}" actualizada';
    }
    action.status = AiActionStatus.done;
    ref.invalidate(ownerProductsProvider(tenantId));
    // New state object so the view rebuilds with the updated action status.
    state = AiChatState(
      messages: List<AiChatMessage>.of(state.messages),
      quota: state.quota,
    );
    return done;
  }

  void dismiss(AiAction action) {
    action.status = AiActionStatus.dismissed;
    state = AiChatState(
      messages: List<AiChatMessage>.of(state.messages),
      quota: state.quota,
    );
  }

  void clear() {
    state = AiChatState(quota: state.quota);
  }
}

final aiChatControllerProvider =
    NotifierProvider.autoDispose<AiChatController, AiChatState>(
      AiChatController.new,
    );
