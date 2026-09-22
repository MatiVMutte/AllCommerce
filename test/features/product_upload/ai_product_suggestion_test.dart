import 'package:all_commerce/features/product_upload/data/models/ai_product_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson with null price and sku', () {
    final AiProductSuggestion s = AiProductSuggestion.fromJson(
      <String, dynamic>{
        'title': 'Vaso',
        'description': 'Acero',
        'category': 'home',
        'tags': <String>['vaso'],
        'suggested_price_ars': null,
        'sku': null,
      },
    );
    expect(s.suggestedPriceArs, isNull);
    expect(s.sku, isNull);
    expect(s.title, 'Vaso');
  });

  test('fromJson with numeric price and sku', () {
    final AiProductSuggestion s = AiProductSuggestion.fromJson(
      <String, dynamic>{
        'title': 'Vaso',
        'description': '',
        'category': 'zzz',
        'tags': <dynamic>[],
        'suggested_price_ars': 8500,
        'sku': 'V-1',
      },
    );
    expect(s.suggestedPriceArs, 8500.0);
    expect(s.sku, 'V-1');
    // unknown category is kept as string; the form maps it via fromId
    expect(s.category, 'zzz');
  });
}
