import 'dart:typed_data';

/// What the AI proposes — never executes by itself. The owner confirms in
/// the chat card and the app runs it through the normal repositories (RLS).
enum AiActionType {
  product,
  stockUpdate,
  priceUpdate,
  productActive,
  productFeatured,
  productDiscount,
  bulkPriceChange;

  static AiActionType fromId(String id) {
    return switch (id) {
      'stock_update' => AiActionType.stockUpdate,
      'price_update' => AiActionType.priceUpdate,
      'product_active' => AiActionType.productActive,
      'product_featured' => AiActionType.productFeatured,
      'product_discount' => AiActionType.productDiscount,
      'bulk_price_change' => AiActionType.bulkPriceChange,
      _ => AiActionType.product,
    };
  }
}

enum AiActionStatus { pending, done, dismissed }

/// One proposed change on a model message.
class AiAction {
  AiAction({required this.type, required this.data, this.imageBytes});

  final AiActionType type;
  final Map<String, dynamic> data;

  /// Photo that came with the triggering user message — used to create the
  /// product's image when a `product` action is confirmed.
  final Uint8List? imageBytes;

  AiActionStatus status = AiActionStatus.pending;

  factory AiAction.fromJson(
    Map<String, dynamic> json, {
    Uint8List? imageBytes,
  }) {
    final Map<String, dynamic> data = Map<String, dynamic>.of(json)
      ..remove('type');
    return AiAction(
      type: AiActionType.fromId(json['type'] as String? ?? ''),
      data: data,
      imageBytes: imageBytes,
    );
  }

  String get productTitle =>
      (data['product_title'] ?? data['title'] ?? '').toString();

  /// Short summary for the confirmation card.
  String describe() {
    return switch (type) {
      AiActionType.product =>
        'Producto nuevo: "${data['title']}" · '
            '${data['category']} · ${data['price'] != null ? '\$${data['price']}' : 'sin precio'}',
      AiActionType.stockUpdate =>
        'Stock de "${data['product_title']}" → ${data['stock']}',
      AiActionType.priceUpdate =>
        'Precio de "${data['product_title']}" → \$${data['price']}',
      AiActionType.productActive =>
        data['is_active'] == true
            ? 'Reactivar "${data['product_title']}"'
            : 'Pausar "${data['product_title']}"',
      AiActionType.productFeatured =>
        data['is_featured'] == true
            ? 'Destacar "${data['product_title']}"'
            : 'Quitar "${data['product_title']}" de destacados',
      AiActionType.productDiscount =>
        data['compare_at_price'] != null
            ? 'Oferta en "${data['product_title']}": \$${data['price']} '
                  '(antes \$${data['compare_at_price']})'
            : 'Quitar oferta de "${data['product_title']}" → \$${data['price']}',
      AiActionType.bulkPriceChange => _describeBulkPrice(data),
    };
  }

  static String _describeBulkPrice(Map<String, dynamic> data) {
    final num pct = (data['percent'] as num?) ?? 0;
    final String sign = pct >= 0 ? '+$pct%' : '$pct%';
    final String? cat = data['category'] as String?;
    final int? count = (data['affected_count'] as num?)?.toInt();
    final String scope = cat != null && cat.isNotEmpty
        ? 'categoría "$cat"'
        : 'todos los productos';
    final String suffix = count != null ? ' ($count)' : '';
    return 'Ajustar precios $sign en $scope$suffix';
  }
}

/// One chat bubble (user or model). Proposals live on model messages.
class AiChatMessage {
  AiChatMessage({
    required this.isUser,
    required this.text,
    this.imageBytes,
    List<AiAction>? actions,
    this.isError = false,
  }) : actions = actions ?? <AiAction>[];

  final bool isUser;
  final String text;
  final Uint8List? imageBytes;
  final List<AiAction> actions;
  final bool isError;

  /// Wire format for the edge function (text turns only).
  Map<String, String> toJson() => <String, String>{
    'role': isUser ? 'user' : 'model',
    'text': text,
  };
}
