import 'package:all_commerce/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiAction', () {
    test('parses each proposal type from the edge function payload', () {
      final Map<String, AiActionType> cases = <String, AiActionType>{
        'product': AiActionType.product,
        'stock_update': AiActionType.stockUpdate,
        'price_update': AiActionType.priceUpdate,
        'product_active': AiActionType.productActive,
        'product_featured': AiActionType.productFeatured,
        'product_discount': AiActionType.productDiscount,
        'bulk_price_change': AiActionType.bulkPriceChange,
      };
      for (final MapEntry<String, AiActionType> e in cases.entries) {
        final AiAction a = AiAction.fromJson(<String, dynamic>{
          'type': e.key,
          'product_id': 'p1',
        });
        expect(a.type, e.value, reason: e.key);
        expect(a.status, AiActionStatus.pending);
      }
    });

    test('fromJson strips the type key out of data', () {
      final AiAction a = AiAction.fromJson(<String, dynamic>{
        'type': 'product',
        'title': 'Yerba',
        'price': 5000,
      });
      expect(a.data.containsKey('type'), isFalse);
      expect(a.data['title'], 'Yerba');
    });

    test('describe() summarizes each action for the confirm card', () {
      expect(
        AiAction.fromJson(<String, dynamic>{
          'type': 'product',
          'title': 'Yerba',
          'category': 'food',
          'price': 5000,
        }).describe(),
        contains('Yerba'),
      );
      expect(
        AiAction.fromJson(<String, dynamic>{
          'type': 'stock_update',
          'product_title': 'Coca',
          'stock': 10,
        }).describe(),
        'Stock de "Coca" → 10',
      );
      expect(
        AiAction.fromJson(<String, dynamic>{
          'type': 'product_active',
          'product_title': 'Coca',
          'is_active': false,
        }).describe(),
        'Pausar "Coca"',
      );
      expect(
        AiAction.fromJson(<String, dynamic>{
          'type': 'product_featured',
          'product_title': 'Coca',
          'is_featured': true,
        }).describe(),
        'Destacar "Coca"',
      );
      expect(
        AiAction.fromJson(<String, dynamic>{
          'type': 'product_discount',
          'product_title': 'Coca',
          'price': 1500,
          'compare_at_price': 2000,
        }).describe(),
        'Oferta en "Coca": \$1500 (antes \$2000)',
      );
      expect(
        AiAction.fromJson(<String, dynamic>{
          'type': 'bulk_price_change',
          'percent': 10,
          'affected_count': 24,
        }).describe(),
        'Ajustar precios +10% en todos los productos (24)',
      );
    });

    test('productTitle falls back to the draft title', () {
      final AiAction a = AiAction.fromJson(<String, dynamic>{
        'type': 'product',
        'title': 'Nuevo',
      });
      expect(a.productTitle, 'Nuevo');
    });
  });

  group('AiChatMessage', () {
    test('toJson maps user/model roles for the wire', () {
      expect(
        AiChatMessage(isUser: true, text: 'hola').toJson(),
        <String, String>{'role': 'user', 'text': 'hola'},
      );
      expect(
        AiChatMessage(isUser: false, text: 'ok').toJson(),
        <String, String>{'role': 'model', 'text': 'ok'},
      );
    });
  });
}
